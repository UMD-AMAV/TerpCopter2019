%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node: estimation 
%
% Purpose:  
% The purpose of the estimation node is to compute an estimate of the
% quadcopters state from noisy sensor data. This may include fusing data
% from different sources (e.g., barometer and lidar for altittude),
% filtering noisy signals (e.g., low-pass filters), implementing
% state estimators (e.g., kalman filters) and navigation algorithms.
%
% Input:
%   - ROS topics: several sensor data topics
%           /mavros/imu/data
%           /terarangerone
%
%   - ROS topic: /features (generated by vision)
%   
% Output:
%   - ROS topic: /stateEstimate (used by control, autonomy, vision, planning)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prepare workspace
clear; close all; clc; format compact;
global imuMsg lidarMsg inertial_yaw_initial; %where to clear them?
run('loadParams.m');
addpath('../');

%run('updatePaths.m');
fprintf('Estimation Node Launching...\n');

% intialize ros node
if(~robotics.ros.internal.Global.isNodeActive)
    rosinit;
end

estimationNode = robotics.ros.Node('/estimation');
imuDataSubscriber = robotics.ros.Subscriber(estimationNode,'/mavros/imu/data','sensor_msgs/Imu',@imuCallback,"BufferSize",1);
lidarDataSubscriber = robotics.ros.Subscriber(estimationNode,'/terarangerone','sensor_msgs/Range',@lidarCallback,"BufferSize",1);
stateEstimatePublisher = robotics.ros.Publisher(estimationNode,'/stateEstimate','terpcopter_msgs/stateEstimate');

stateMsg = rosmessage('terpcopter_msgs/stateEstimate');
%stateMsg.Range = 0.2;
t0 = [];

% lidar data receiver
    imuMsg = receive(imuDataSubscriber,20);
    lidarMsg = receive(lidarDataSubscriber,20);

r = robotics.Rate(30);
reset(r);

% smooting filter
a = 0;
b = 0;
c = 0;
d = 0;
e = 0;
f = 0;
g = 0;
h = 0;
i = 0;
j = 0;

while(1)
    % Imu data receiver
    %imuMsg = receive(imuDataSubscriber,3);
    if isempty(imuMsg)
        state = NaN;
        disp('No imu data\n');
        return;
    end
    w = imuMsg.Orientation.W;
    x = imuMsg.Orientation.X;
    y = imuMsg.Orientation.Y;
    z = imuMsg.Orientation.Z;

    euler = quat2eul([w x y z]);
    %yaw measured clock wise is negative.
    state.psi_inertial = rad2deg(euler(1));
    state.theta = rad2deg(euler(2));
    state.phi = rad2deg(euler(3));

    %get relative yaw = - inertial yaw_intial - inertial yaw 
    if isempty(inertial_yaw_initial), inertial_yaw_initial = state.psi_inertial; end
    state.psi_relative = inertial_yaw_initial - state.psi_inertial;

    %rounding off angles to 1 decimal place
    state.psi_inertial = round(state.psi_inertial,1);
    state.psi_relative = round(state.psi_relative,1);
    state.theta = round(state.theta,1);
    state.phi = round(state.phi,1);

    %yaw lies between [-180 +180];
    if state.psi_relative> 180, state.psi_relative = state.psi_relative-360;
    elseif state.psi_relative<-180, state.psi_relative = 360+state.psi_relative;end

    % condition lidar reading
    if isempty(lidarMsg) || lidarMsg.Range_ <= 0.2
        disp('no lidar data');
        %get min range from lidar msg
        stateMsg.Range = 0.2;
    else
        % moving average filter
        i = j;
        h = i;
        g = h;
        f = g;
        e = f;
        d = e;
        c = d;
        b = c;
        a = b;
        j = lidarMsg.Range_;
        smoothed_range = (a+b+c+d+e+f+g+h+i+j)/10;
        
        stateMsg.Range = smoothed_range;
    end
     
    %lidar data is in imu frame; convert to inertial frame
    % phi and theta are in deg. so use cosd to calculate the compensated range
    stateMsg.Range = cosd(state.phi)*cosd(state.theta)*stateMsg.Range;
    stateMsg.Range = round(stateMsg.Range,2);
    %change Up to the estimated output from the filter instead of from the
    %range 
    stateMsg.Up = stateMsg.Range;
    
    stateMsg.Yaw = state.psi_relative;
    stateMsg.Roll = state.phi;
    stateMsg.Pitch = state.theta;
    
    % timestamp
    ti= rostime('now');
    abs_t = eval([int2str(ti.Sec) '.' ...
        int2str(ti.Nsec)]);
   
    if isempty(t0), t0 = abs_t; end
    t = abs_t-t0;
    stateMsg.Time = t;
    
    % fixed loop pause
    waitfor(r);
    
    % publish stateEstimate
    send(stateEstimatePublisher,stateMsg);

end

