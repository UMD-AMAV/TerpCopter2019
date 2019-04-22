%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node: autonomy
%
% Reference: stateEstimate.msg
% float32 range
% float32 time
% float32 north
% float32 east
% float32 up
% float32 yaw
% float32 pitch
% float32 roll
%
% Reference: ayprCmd.msg
% ayprCmdMsg = rosmessage(ayprCmdPublisher);
% ayprCmdMsg.AltDesiredMeters = 0;
% ayprCmdMsg.YawDesiredDeg = 0;
% ayprCmdMsg.PitchDesiredDeg = 0;
% ayprCmdMsg.RollDesiredDeg = 0;
% ayprCmdMsg.AltSwitch = 0;
% ayprCmdMsg.YawSwitch = 0;
% ayprCmdMsg.PitchSwitch = 0;
% ayprCmdMsg.RollSwitch = 0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prepare workspace
clear; close all; clc; format compact;
addpath('../')
params = loadParams();

% missions
mission = loadMission_takeoffHoverLand(); % yaw pitch roll (manual)
% mission = loadMission_takeoffHoverPointLand();  % pitch, roll (manual)
% mission = loadMission_takeoffHoverFixedOrientLand(); % autonomous w/drift
% TODO: mission = loadMission_takeoffHoverOverHLand(); % 1 point



%mission = loadMissionAltModeTest(); %hover test

fprintf('Launching Autonomy Node...\n');

global timestamps

% initialize ROS
if(~robotics.ros.internal.Global.isNodeActive)
    rosinit;
end

% Subscribers
stateEstimateSubscriber = rossubscriber('/stateEstimate');
startMissionSubscriber = rossubscriber('/startMission', 'std_msgs/Bool');

% vision-based subscribers depend on mission
if ( mission.config.H_detector )
    % subscribe to H camera node
end
if ( mission.config.target_detector )
    yawErrorCameraSubscriber = rossubscriber('/yawSetpoint');
    targetDetectionFlagSubscriber = rossubscriber('/targetFlag', 'std_msgs/Bool');
end
if ( mission.config.flowProbe )
    flowProbeDataSubscriber = rossubscriber('/terpcopter_flow_probe_node/flowProbe');
end

% Publishers
ayprCmdPublisher = rospublisher('/ayprCmd', 'terpcopter_msgs/ayprCmd');
pause(0.1)

% Unpacking Initial ROS Messages
[ayprCmdMsg] = default_aypr_msg(ayprCmdPublisher);

% initial variables
stick_thrust = -1;

r = robotics.Rate(10);
reset(r);

% for logging
currentBehavior = 1;
logFlag = 1;
dateString = datestr(now,'mmmm_dd_yyyy_HH_MM_SS_FFF');
autonomyLog = [params.env.matlabRoot '/autonomy_' dateString '.log'];

if ( strcmp(params.auto.mode,'auto'))
    send(ayprCmdPublisher, ayprCmdMsg);
    
    % This enables the capability to start the mission through the TunerGUI
    startMissionFlag = false;
    startMissionMsg = receive(startMissionSubscriber);
    startMissionFlag = startMissionMsg.Data;
    
    while(1)
        
        % get latest messages
        stateEstimateMsg = stateEstimateSubscriber.LatestMessage;
        
        if ( mission.config.H_detector )
            % subscribe to H camera node
        end
        if ( mission.config.target_detector )
            yawErrorCameraMsg = yawErrorCameraSubscriber.LatestMessage;
            targetDetectionFlagMsg = targetDetectionFlagSubscriber.LatestMessage;
        end
        if ( mission.config.flowProbe )
            fpMsg = flowProbeDataSubscriber.LatestMessage;
        end
        
        % unpack statestimate
        t = stateEstimateMsg.Time;
        z = stateEstimateMsg.Up;
        fprintf('Received Msg, Quad Alttiude is : %3.3f m\n', z );
        
        
        % initialize and time-stamps on first-loop iteration
        if mission.config.firstLoop == 1
            disp('Behavior Manager Started')
            % initialize time variables
            timestamps.initial_event_time = t;
            timestamps.behavior_switched_timestamp = t;
            timestamps.behavior_satisfied_timestamp = t;
            mission.config.firstLoop = false; % ends the first loop
        end
        
        name = mission.bhv{1}.name;
        flag = mission.bhv{1}.completion.status;
        ayprCmd = mission.bhv{1}.ayprCmd;
        completion = mission.bhv{1}.completion;
        
        totalTime = t - timestamps.initial_event_time;
        bhvTime = t - timestamps.behavior_switched_timestamp;
        
        fprintf('Current Behavior: %s\tTime Spent in Behavior: %f\t Total Time of Mission: %f \n\n',name,bhvTime,totalTime);
        
        % if behavior completes pop behavior
        if flag == true
            [mission.bhv] = pop(mission.bhv, t);
            currentBehavior = currentBehavior + 1;
            disp('**** Popped Behavior ****');
        else
            % check status of remaining behavior
            %Set Handles within each behavior
            switch name
                % basic behaviors
                case 'bhv_takeoff'
                    completionFlag = bhv_takeoff( stateEstimateMsg , ayprCmd , mission.bhv{1}.thresholdDist );
                case 'bhv_hover'
                    completionFlag = bhv_hover(stateEstimateMsg, ayprCmd, completion, t);
                case 'bhv_hover_fixed_orient'
                    completionFlag = bhv_hover_fixed_orient(stateEstimateMsg, ayprCmd, completion, t);
                case 'bhv_point_to_direction'
                    completionFlag = bhv_point_to_direction(stateEstimateMsg, ayprCmd, completion, t);
                case 'bhv_land'
                    completionFlag = bhv_land(stateEstimateMsg, ayprCmd, completion, t, init);
                    
                    % TODO:
                    
                    % basic behvaiors (Zach, Ian, Jerrar)
                    % 'bhv_fly_forward'
                    
                    % servo behaviors (Zach, Ian)
                    % 'bhv_hover_openServo'
                    % 'bhv_hover_closeServo'
                    
                    % flow-probe behaviors (Rohan)
                    % 'bhv_fly_forward_flowprobe'
                    
                    % vision behaviors (Abhinav, Kay)
                    % 'bhv_hover_over_H'
                    % 'bhv_align_over_H'
                    
                    % vision behaviors (Krishna)
                    % 'bhv_scan_for_target'
                    % 'bhv_point_to_target'
                    % 'bhv_move_to_target'
                    
                    
                    %                 case 'bhv_hover_over_H'
                    %                     [completionFlag, ayprCmd] = bhv_hover_over_H(stateEstimateMsg, ayprCmd, completion, t);
                    %                     % update ayprCmd
                    %                     mission.bhv{1}.ayprCmd = ayprCmd;
                    %                 case 'bhv_point_to_target'
                    %                     [completionFlag] = bhv_point_to_target(stateEstimateMsg, yawErrorCameraMsg, aypr, completion, t);
                    %                     ayprCmdMsg.HeadingRad = yawErrorCameraMsg.Data;
                    
                otherwise
            end
            mission.bhv{1}.completion.status = completionFlag;
        end
        
        % publish
        ayprCmdMsg = mission.bhv{1}.ayprCmd;s
        send(ayprCmdPublisher, ayprCmdMsg);
        fprintf('Published Ahs Cmd. Alt : %3.3f \t Yaw: %3.3f\n', ayprCmdMsg.AltitudeMeters, ayprCmdMsg.HeadingRad);
        waitfor(r);
        
        if ( logFlag )
            pFile = fopen( autonomylog ,'a');
            
            % write csv file
            fprintf(pFile,'%6.6f,',t);
            fprintf(pFile,'%d,',currentBehavior);
            
            fprintf(pFile,'%6.6f,',ayprCmdMsg.AltDesiredMeters);
            fprintf(pFile,'%6.6f,',ayprCmdMsg.YawDesiredDeg);
            fprintf(pFile,'%6.6f,',ayprCmdMsg.PitchDesiredDeg);
            fprintf(pFile,'%6.6f,',ayprCmdMsg.RollDesiredDeg);
            fprintf(pFile,'%6.6f,',ayprCmdMsg.AltSwitch);
            fprintf(pFile,'%6.6f,',ayprCmdMsg.YawSwitch);
            fprintf(pFile,'%6.6f,',ayprCmdMsg.PitchSwitch);
            fprintf(pFile,'%6.6f,',ayprCmdMsg.RollSwitch);
            
            fprintf(pFile,'%6.6f,',stateEstimateMsg.Range);
            fprintf(pFile,'%6.6f,',stateEstimateMsg.Time);
            fprintf(pFile,'%6.6f,',stateEstimateMsg.North);
            fprintf(pFile,'%6.6f,',stateEstimateMsg.East);
            fprintf(pFile,'%6.6f,',stateEstimateMsg.Up);
            fprintf(pFile,'%6.6f,',stateEstimateMsg.Yaw);
            fprintf(pFile,'%6.6f,',stateEstimateMsg.Pitch);
            fprintf(pFile,'%6.6f,\n',stateEstimateMsg.Roll);
            
            fclose(pFile);
        end
        
    end
end
%
%     if ( strcmp(params.auto.mode, 'manual'))
%     fprintf('Autonomy Mode: Manual');
%
%     send(openLoopIsActivePublisher, openLoopIsActiveMsg);
%     send(closedLoopIsActivePublisher, closedLoopIsActiveMsg);
%
%     send(pidAltSettingPublisher, pidAltSettingMsg);
%     send(pidYawSettingPublisher, pidYawSettingMsg);
%     send(ahsCmdPublisher, ayprCmdMsg);
%     send(openLoopIsActivePublisher, openLoopIsActiveMsg);
%     send(closedLoopIsActivePublisher, closedLoopIsActiveMsg);
%
%     while(1)
%         waitfor(r);
%     end
% end
