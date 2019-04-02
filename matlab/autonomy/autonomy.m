%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node: autonomy
%
% Purpose:  
% The purpose of the autonomy node is to generate, monitor, and manipulate 
% a queue of behaviors that define mission and safety objectives. The 
% behaviors are initially specified in a mission configuration file that is 
% read by the autonomy node at the start of a run. Each behavior is used to
% accomplish a specific task by generating appropriate 'ahsCommands' of 
% [altitude, heading, forward speed, crab speed] to be used as setpoints
% by the control node. A single behavior might only generate a subset of 
% such commands. The functionality of each behavior will be encapsulated in 
% a .m file with the prefix: BHV_ .
% 
% Examples of mission behaviors include:
%   - BHV_Takeofff 
%   - BHV_ConstantAltitude
%   - BHV_ConstantHeadingSpeed
%   - BHV_PositionHold
%   - BHV_Land
%   - BHV_FollowWpts
%   - BHV_KeepTargetCentered 
%
% Examples of safety behaviors include:
%   - BHV_LowBatteryLanding
%   - BHV_OpRegion
%   - BHV_AvoidObstacle
%
% A behavior manager will monitor the progress of each behavior. When the
% behavior (or set of behaviors) indicate they are 'complete' they will 
% become inactive and the next set of behaviros in the mission will become 
% active. Safety behaviors will be used to over-ride existing mission
% behaviors in emergency situations.
%
% The autonomy node may also perform some other relevant services such as
% path planning.
%
% Input: 
%   - ROS topic: /stateEstimate (generated by estimation)
%   - ROS topic: /features (generated by vision)
%   
% Output:
%   - ROS topic: /ahsCmd (used by control)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prepare workspace
clear; close all; clc; format compact;
addpath('../')
params = loadParams();
mission = loadMissionTest2(); %hover test 
fprintf('Launching Autonomy Node...\n');

global timestamps

% initialize ROS
if(~robotics.ros.internal.Global.isNodeActive)
    rosinit;
end
    
% Subscribers
stateEstimateSubscriber = rossubscriber('/stateEstimate');
startMissionSubscriber = rossubscriber('/startMission', 'std_msgs/Bool');
% yawErrorCameraSubscriber = rossubscriber('/yawSetpoint');
% targetDetectionFlagSubscriber = rossubscriber('/targetFlag', 'std_msgs/Bool');

% Publishers
ahsCmdPublisher = rospublisher('/ahsCmd', 'terpcopter_msgs/ahsCmd');
closedLoopIsActivePublisher = rospublisher('/closedLoopIsActive', 'std_msgs/Bool');
openLoopIsActivePublisher = rospublisher('/openLoopIsActive', 'std_msgs/Bool');
openLoopStickCmdPublisher = rospublisher('/openLoopStickCmd', 'terpcopter_msgs/openLoopStickCmd');
pidAltSettingPublisher = rospublisher('/pidAltSetting', 'terpcopter_msgs/ffpidSetting');
pidYawSettingPublisher = rospublisher('/pidYawSetting', 'terpcopter_msgs/ffpidSetting');
servoSwitchCmdPublisher = rospublisher('/servoSwitch', 'std_msgs/Bool');

pause(0.1)

% Unpacking Initial ROS Messages
ahsCmdMsg = rosmessage(ahsCmdPublisher);
ahsCmdMsg.AltitudeMeters = 0;
ahsCmdMsg.HeadingRad = 0;
ahsCmdMsg.ForwardSpeedMps = 0;
ahsCmdMsg.CrabSpeedMps = 0;

openLoopIsActiveMsg = rosmessage(openLoopIsActivePublisher);
openLoopIsActiveMsg.Data = false;

closedLoopIsActiveMsg = rosmessage(closedLoopIsActivePublisher);
closedLoopIsActiveMsg.Data = false;

openLoopStickCmdMsg = rosmessage(openLoopStickCmdPublisher);
openLoopStickCmdMsg.Thrust = 0;
openLoopStickCmdMsg.Yaw = 0;
openLoopStickCmdMsg.Pitch = 0;
openLoopStickCmdMsg.Roll = 0;

pidAltSettingMsg = rosmessage(pidAltSettingPublisher);
pidAltSettingMsg.Kp = params.ctrl.altitudeGains.kp;
pidAltSettingMsg.Ki = params.ctrl.altitudeGains.ki;
pidAltSettingMsg.Kd = params.ctrl.altitudeGains.kd;
pidAltSettingMsg.Ff = params.ctrl.altitudeGains.ffterm;

pidYawSettingMsg = rosmessage(pidYawSettingPublisher);
pidYawSettingMsg.Kp = params.ctrl.yawGains.kp;
pidYawSettingMsg.Ki = params.ctrl.yawGains.ki;
pidYawSettingMsg.Kd = params.ctrl.yawGains.kd;
pidYawSettingMsg.Ff = 0;


% initial variables
stick_thrust = -1;

r = robotics.Rate(10);
reset(r);

if ( strcmp(params.auto.mode,'auto'))
    send(pidAltSettingPublisher, pidAltSettingMsg);
    send(pidYawSettingPublisher, pidYawSettingMsg);
    send(ahsCmdPublisher, ahsCmdMsg);
    send(openLoopIsActivePublisher, openLoopIsActiveMsg);
    send(closedLoopIsActivePublisher, closedLoopIsActiveMsg);
    send(openLoopStickCmdPublisher, openLoopStickCmdMsg);
    
    % This enables the capability to start the mission through the TunerGUI
    startMissionFlag = false;
    startMissionMsg = receive(startMissionSubscriber);
    startMissionFlag = startMissionMsg.Data;
    
    while(1)
        stateEstimateMsg = stateEstimateSubscriber.LatestMessage;
%         yawErrorCameraMsg = yawErrorCameraSubscriber.LatestMessage;
%         targetDetectionFlagMsg = targetDetectionFlagSubscriber.LatestMessage;

        % unpack statestimate
        t = stateEstimateMsg.Time;
        z = stateEstimateMsg.Up;
        % fprintf('Received Msg, Quad Alttiude is : %3.3f m\n', z );

        currentBehavior = 1; 
        
        if mission.config.firstLoop == 1
            disp('Behavior Manager Started')
            % initialize time variables 
            timestamps.initial_event_time = t;  
            timestamps.behavior_switched_timestamp = t;
            timestamps.behavior_satisfied_timestamp = t;
            mission.config.firstLoop = false; % ends the first loop
        end

        % Logic for the Target Detection 
        %%%%%%%%%%%%%%
%         if (targetDetectionFlagMsg.Data && behavior.bhv{1}.initialDetection == true)
%             fprintf(' Detected Target Flag');
%             [mission.bhv] = push(mission.bhv, behavior.bhv{1});
%             behavior.bhv{1}.initialDetection = false;
%         end
        %%%%%%%%%%%%%%
        
        name = mission.bhv{currentBehavior}.name;
        flag = mission.bhv{currentBehavior}.completion.status;
        ahs = mission.bhv{currentBehavior}.ahs;
        completion = mission.bhv{currentBehavior}.completion;
        
        totalTime = t - timestamps.initial_event_time;
        bhvTime = t - timestamps.behavior_switched_timestamp;
        
        fprintf('Current Behavior: %s\tTime Spent in Behavior: %f\t Total Time of Mission: %f \n\n',name,bhvTime,totalTime); 

        if flag == true
            [mission.bhv] = pop(mission.bhv, t);
        else  
            %Set Handles within each behavior
            
            %switch to 
            %Eval command eval([mission.bhv(CurrentBehavior).name,status)
            switch name
                case 'bhv_takeoff'
                    %disp('takeoff behavior');
                    [completionFlag, stick_thrust] = bhv_takeoff_status(stateEstimateMsg, ahs, stick_thrust);
                    openLoopIsActiveMsg.Data = true;      % true: openloop control
                    closedLoopIsActiveMsg.Data = false;
                    openLoopStickCmdMsg.Thrust = stick_thrust;
                case 'bhv_hover'
                    %disp('hover behavior');
                    [completionFlag] = bhv_hover_status(stateEstimateMsg, ahs, completion, t);
                    ahsCmdMsg.AltitudeMeters = mission.bhv{currentBehavior}.ahs.desiredAltMeters;
                    openLoopIsActiveMsg.Data = false;      % true: openloop control
                    closedLoopIsActiveMsg.Data = true;
                case 'bhv_point_to_direction'
                    %disp('point to direction behavior')
                    [completionFlag] = bhv_point_to_direction_status(stateEstimateMsg, ahs, completion, t);
                case 'bhv_land'
                    %disp('landing behavior');
                    init = mission.bhv{currentBehavior}.initialize;
                    [completionFlag, initialize, ahsUpdate] = bhv_landing_status(stateEstimateMsg, ahs, completion, t, init);
                    display(initialize)
                    mission.bhv{currentBehavior}.initialize.firstLoop = initialize;
                    ahsCmdMsg.AltitudeMeters = ahsUpdate;
                case 'bhv_land_open'
                    [completionFlag, stick_thrust_land] = bhv_landing_open_status(stateEstimateMsg, ahs, completion);
                    openLoopIsActiveMsg.Data = true;      % true: openloop control
                    closedLoopIsActiveMsg.Data = false;
                    openLoopStickCmdMsg.Thrust = stick_thrust_land;
                case 'bhv_point_to_target'
                    [completionFlag] = bhv_point_to_target_status(stateEstimateMsg, yawErrorCameraMsg, ahs, completion, t);
                    ahsCmdMsg.HeadingRad = yawErrorCameraMsg.Data;
                otherwise  
            end
            mission.bhv{currentBehavior}.completion.status = completionFlag;
        end

        % publish
        send(pidAltSettingPublisher, pidAltSettingMsg);
        send(pidYawSettingPublisher, pidYawSettingMsg);
        send(ahsCmdPublisher, ahsCmdMsg);
        send(openLoopIsActivePublisher, openLoopIsActiveMsg);
        send(closedLoopIsActivePublisher, closedLoopIsActiveMsg);
        send(openLoopStickCmdPublisher, openLoopStickCmdMsg);
        fprintf('Published Ahs Cmd. Alt : %3.3f \t Yaw: %3.3f\n', ahsCmdMsg.AltitudeMeters, ahsCmdMsg.HeadingRad);
        
        waitfor(r);
    end
elseif ( strcmp(params.auto.mode, 'manual'))
    fprintf('Autonomy Mode: Manual');
    send(pidAltSettingPublisher, pidAltSettingMsg);
    send(pidYawSettingPublisher, pidYawSettingMsg);
    send(ahsCmdPublisher, ahsCmdMsg);
    
    while(1)
        waitfor(r);
    end
end