%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node: control
%
% Purpose:  
% The purpose of the control node is to regulate the quadcopter to desired
% setpoints of [altitude, heading, forward speed, crab speed]. We refer to
% this as a 'ahsCmd' which is generated by a behavior in the autonomy node.
% The control node determines the appropriate 'stickCmd' [yaw, pitch, roll,
% thrust] to send to the virtual_transmitter.
%
% Input:
%   - ROS topic: /stateEstimate (generated by estimation)
%   - ROS topic: /ahsCmd (generated by autonomy)
%   
% Output:
%   - ROS topic: /stickCmd (used by virtual_transmitter)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prepare workspace
clear; close all; clc; format compact;
addpath('../')
params = loadParams();

global controlParams
controlParams = params.ctrl;
fprintf('Control Node Launching...\n');

% declare global variables
% Determine usage in other scripts - change to local if no other usage
global altitudeErrorHistory;
global forwardErrorHistory;
altitudeErrorHistory.lastVal = 0;
altitudeErrorHistory.lastSum = 0;
altitudeErrorHistory.lastTime = 0;
% 
% yawError.lastVal = 0;
% yawError.lastSum = 0;
% yawError.lastTime = 0;
forwardErrorHistory.lastVal = 0;
forwardErrorHistory.lastSum = 0;
forwardErrorHistory.lastTime = 0;

% initialize ROS
if(~robotics.ros.internal.Global.isNodeActive)
    rosinit;
end

% Subscribers
stateEstimateSubscriber = rossubscriber('/stateEstimate');

ahsCmdSubscriber = rossubscriber('/ahsCmd');

% yawSetpointSubscriber = rossubscriber('/yawSetpoint');

pidAltSettingSubscriber = rossubscriber('/pidAltSetting');
pidResetPublisher = rospublisher('/pidReset', 'std_msgs/Bool');
pidResetSubscriber = rossubscriber('/pidReset');

pidYawSettingSubscriber = rossubscriber('/pidYawSetting', 'terpcopter_msgs/ffpidSetting');

% % smoothing filter
% a = 0;
% b = 0;
% c = 0;
% d = 0;
% e = 0;
% f = 0;
% g = 0;
% h = 0;
% i = 0;
% j = 0;
% 
% k = 0;
% l = 0;
% m = 0;
% n = 0;
% o = 0;
% p =0;
% q=0;
% AA=0;
% s=0;

% Publishers
stickCmdPublisher = rospublisher('/stickCmd', 'terpcopter_msgs/stickCmd');

pause(2)
stickCmdMsg = rosmessage(stickCmdPublisher);
stickCmdMsg.Thrust = 0;
stickCmdMsg.Yaw = 0;
stickCmdMsg.Pitch = 0;

stateEstimateMsg = stateEstimateSubscriber.LatestMessage;

ahsCmdMsg = ahsCmdSubscriber.LatestMessage;

pidAltSettingMsg = pidAltSettingSubscriber.LatestMessage;
pidYawSettingMsg = pidYawSettingSubscriber.LatestMessage;

% yawSetpointMsg = yawSetpointSubscriber.LatestMessage;

% timestamp
t0 = []; timeMatrix=[];
ti= rostime('now');
%abs_t = eval([int2str(ti.Sec) '.' ...
    %int2str(ti.Nsec)]);

abs_t = double(ti.Sec)+double(ti.Nsec)*10^-9;

if isempty(t0), t0 = abs_t; end


altitudeErrorHistory.lastTime = 0; %stateEstimateMsg.Time;
display("alt meters")
display(ahsCmdMsg.AltitudeMeters)
%display("alt meters")
%display(altitudeErrorHistory.lastVal)
altitudeErrorHistory.lastVal = ahsCmdMsg.AltitudeMeters;
altitudeErrorHistory.lastSum = 0;
altitudeErrorHistory.lastError = 0;
u_t_alt = controlParams.altitudeGains.ffterm;



% absoluteYaw = stateEstimateMsg.Yaw;
% ahsCmdMsg.HeadingRad = absoluteYaw;
% yawError.lastTime = stateEstimateMsg.Time;
% yawError.lastVal = 0; %ahsCmdMsg.HeadingRad;
% yawError.lastSum = 0;
u_t_yaw = 0; 

forwardErrorHistory.lastTime = 0; %stateEstimateMsg.Time;
forwardErrorHistory.lastVal = ahsCmdMsg.ForwardSpeedMps;
forwardErrorHistory.lastSum = 0;
forwardErrorHistory.log=[params.env.matlabRoot '/forwardSpeedControl_' datestr(now,'mmmm_dd_yyyy_HH_MM_SS_FFF') '.log'];

u_t_forward = 0;


disp('initialize loop');

r = robotics.Rate(10);
reset(r);

send(stickCmdPublisher, stickCmdMsg);

while(1)
    stateEstimateMsg = stateEstimateSubscriber.LatestMessage;
    ahsCmdMsg = ahsCmdSubscriber.LatestMessage;
    pidAltSettingMsg = pidAltSettingSubscriber.LatestMessage;
    pidYawSettingMsg = pidYawSettingSubscriber.LatestMessage;
    
%     yawSetpointMsg = yawSetpointSubscriber.LatestMessage;


    % timestamp
    ti= rostime('now');
    abs_t = double(ti.Sec)+double(ti.Nsec)*10^-9;
    t = abs_t-t0;
    %timeMatrix = [timeMatrix;t];
    %if isempty(t0), t0 = abs_t; end
   
    %fprintf("t %6.4f",t);

    % unpack statestimate
    %t = stateEstimateMsg.Time;
    z = stateEstimateMsg.Range;
    yaw = stateEstimateMsg.Yaw; % - absoluteYaw;
    u = stateEstimateMsg.ForwardVelocity;
    
    %fprintf('Current Quad Alttiude is : %3.3f m\n', z );

    % get setpoint
    z_d = ahsCmdMsg.AltitudeMeters;
    
    %%%% CAHNGING YAW FROM GUI TO VISION %%%%%
%     yaw_d = yawSetpointMsg.Data; % ahsCmdMsg.HeadingRad;
   
u_d = 0.5; %ahsCmdMsg.ForwardSpeedMps;   
    % update errors
    altError = z_d - z;
    forwardError = u_d - u;
    
    % reset Integral
    pidResetMsg = rosmessage('std_msgs/Bool');
    pidResetMsg.Data = false;
    pidResetMsg = pidResetSubscriber.LatestMessage;
    if ~isempty(pidResetMsg)
        if pidResetMsg.Data == true 
            disp("Resetting PID ...")
            altitudeErrorHistory.lastVal = ahsCmdMsg.AltitudeMeters;
            altitudeErrorHistory.lastSum = 0;
            pidResetMsg.Data = false;
            send(pidResetPublisher, pidResetMsg);
        end
    end

    % compute controls
    % FF_PID(gains, error, newTime, newErrVal)
    [u_t_alt, altitudeErrorHistory] = FF_PID(pidAltSettingMsg, altitudeErrorHistory, t, altError);
    disp('pid loop');
    disp(pidAltSettingMsg)
%     disp('yawSetpoint')
%     disp(yaw_d)
    disp('yawCurrent')
      disp(yaw)
      
    
%     %New Yaw Controller
%     yaw_d = deg2rad(yaw_d);
%     yaw = deg2rad(yaw);
%     yawError = (yaw_d - yaw);
%     yawError = (atan2(sin(yawError),cos(yawError)));
%     
%       disp('yawSetpoint')
%       disp(yaw_d)
%       disp('yawCurrent')
%       disp(yaw)
%       disp('yawError')
%       disp(yawError)
% %       disp('yawSetpointError')
% %       disp(yaw_error)
%     
%     u_t_yaw = -pidYawSettingMsg.Kp*yawError;
%     % compute controls
% %      [u_t_yaw, yawError] = PID(pidYawSettingMsg, yawError, t, yaw_error);
% %      disp('yaw control gains');
% %      disp(controlParams.yawGains)
% %      disp('yaw control signal');
% %      disp(u_t_yaw)
    
% FLOW PROBE

    [u_t_forward, forwardErrorHistory] = forwardcontroller_PID(controlParams.forwardGains , forwardErrorHistory, t, forwardError)

    u_t_alt = 2*max(min(1,u_t_alt),0)-1;

%     %calculate net throttle input
%     thr_trim = 0;
%     current_alt = 1;%u_t_alt;
%     % ADD if FOR NO LIDAR DATA OR LOW LIDAR VALUE
%     u_stick_thr_net = (current_alt*controlParams.stick_lim(1) + thr_trim*controlParams.trim_lim(1))...
%                             /(controlParams.stick_lim(1)+controlParams.trim_lim(1))
%     %get slope                    
%     slope = controlParams.m_net * controlParams.g/(u_stick_thr_net+1)
%     
%     %get max allowed thrust in horizontal plane
%     T_XY_max = slope * sqrt(4 - (u_stick_thr_net+1)*(u_stick_thr_net+1)) -1;
%     T_XY_max_tilt = slope*(u_stick_thr_net+1)*cos(stateEstimateMsg.Roll)*cos(stateEstimateMsg.Pitch)*tan(controlParams.tilt_max);
%     T_XY_max = min(T_XY_max,T_XY_max_tilt);
%     
%     %saturateg horizontal thrust setpoints
%     mag = sqrt(u_t_forward*u_t_forward );%+ thr_sp_crab*thr_sp_crab);
%     if mag > T_XY_max
%         u_t_forward = u_t_forward * T_XY_max/mag;
%     end
    
    u_t_pitch = u_t_forward;

    % publish
    
    stickCmdMsg.Thrust = u_t_alt;
    stickCmdMsg.Yaw = max(-1,min(1,u_t_yaw));
    stickCmdMsg.Pitch = max(-1,min(1,u_t_pitch));
    
%     fprintf('Thrust Before: %3.3f\n', stickCmdMsg.Thrust);
%     % moving average filter
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     AA = s;
%     q = AA;
%     p = q;
%     o = p;
%     n = o;
%     m = n;
%     l = m;
%     k = l;
%     j = k;
%     
%     i = j;
%     h = i;
%     g = h;
%     f = g;
%     e = f;
%     d = e;
%     c = d;
%     b = c;
%     a = b;
%     s = stickCmdMsg.Thrust;
%     stickCmdThrustAvg = (a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p+q+AA+s)/18;      
%     
%     if (stickCmdMsg.Thrust > stickCmdThrustAvg + 0.3) || (stickCmdMsg.Thrust < stickCmdThrustAvg - 0.3)
%         stickCmdMsg.Thrust = stickCmdThrustAvg;
%     end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
%     fprintf('Moving Avg: %3.3f \n', stickCmdThrustAvg); 
    send(stickCmdPublisher, stickCmdMsg);
%     fprintf('Stick Cmd.Thrust : %3.3f, Altitude : %3.3f, Altitude_SP : %3.3f, Error : %3.3f, Yaw : %3.3f \n', stickCmdMsg.Thrust , stateEstimateMsg.Up, z_d, ( z - z_d ), u_t_yaw );
    fprintf('control = %3.3f, pitch cmd = %3.3f\n',u_t_pitch,stickCmdMsg.Pitch)
    time = r.TotalElapsedTime;
	%fprintf('Iteration: %d - Time Elapsed: %f\n',i,time)
disp('Controller');
	waitfor(r);
end

