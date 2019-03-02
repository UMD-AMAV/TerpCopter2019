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
mission = loadMissionTest();

fprintf('Launching Autonomy Node...\n');

global timestamps

% initialize ROS
if(~robotics.ros.internal.Global.isNodeActive)
    rosinit;
end
    
% Subscribers
stateEstimateSubscriber = rossubscriber('/stateEstimate');
startMissionSubscriber = rossubscriber('/startMission', 'std_msgs/Bool');


% Publishers
ahsCmdPublisher = rospublisher('/ahsCmd', 'terpcopter_msgs/ahsCmd');
pidAltSettingPublisher = rospublisher('/pidAltSetting', 'terpcopter_msgs/ffpidSetting');
pidYawSettingPublisher = rospublisher('/pidYawSetting', 'terpcopter_msgs/ffpidSetting');

pause(0.1)
ahsCmdMsg = rosmessage(ahsCmdPublisher);
ahsCmdMsg.AltitudeMeters = 0;
ahsCmdMsg.HeadingRad = 0;
ahsCmdMsg.ForwardSpeedMps = 0;
ahsCmdMsg.CrabSpeedMps = 0;

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



r = robotics.Rate(10);
reset(r);

if ( strcmp(params.auto.mode,'auto'))
    send(pidAltSettingPublisher, pidAltSettingMsg);
    send(pidYawSettingPublisher, pidYawSettingMsg);
    send(ahsCmdPublisher, ahsCmdMsg);
    
    startMissionFlag = false;
    startMissionMsg = receive(startMissionSubscriber);
    startMissionFlag = startMissionMsg.Data;
    
    while(1)
%         if(w~=1)
%             disp('not pressed')
%             continue;
%         end
        stateEstimateMsg = stateEstimateSubscriber.LatestMessage;

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

        name = mission.bhv{currentBehavior}.name;
        flag = mission.bhv{currentBehavior}.completion.status;
        %timestamps = mission.variables;
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
                    [completionFlag] = bhv_takeoff_status(stateEstimateMsg, ahs);
                case 'bhv_hover'
                    %disp('hover behavior');
                    [completionFlag] = bhv_hover_status(stateEstimateMsg, ahs, completion, t);
                case 'landing'
                    %disp('landing behavior');
                    [completionFlag, ahs] = bhv_landing_status(stateEstimateMsg, completion, t);
                otherwise
                    
            end
            mission.bhv{currentBehavior}.completion.status = completionFlag;
            z_d = ahs.desiredAltMeters;
        end

        % publish
        ahsCmdMsg.AltitudeMeters = z_d;
        send(ahsCmdPublisher, ahsCmdMsg);
        fprintf('Published Ahs Cmd. Alt : %3.3f \n', z_d );
        
        waitfor(r);
    end
elseif ( strcmp(params.auto.mode, 'manual'))
    fprintf('Autonomy Mode: Manual');
    send(pidAltSettingPublisher, pidAltSettingMsg);
    send(pidYawSettingPublisher, pidYawSettingMsg);
    send(ahsCmdPublisher, ahsCmdMsg);
    
    while(1)
        %send(ahsCmdPublisher, ahsCmdMsg);
        %send(pidSettingPublisher, pidSettingMsg);
        waitfor(r);
    end
end