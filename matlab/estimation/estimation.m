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
%           /mavros/distance_sensor/hrlv_ez4_pub
%           /mavros/vision_pose/pose
%   
% Output:
%   - ROS topic: /stateEstimate (used by control, autonomy, vision, planning)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prepare workspace
clear all; close all; clc; format compact;
run('loadParams.m');
addpath('../');

%run('updatePaths.m');
fprintf('Estimation Node Launching...\n');

% intialize ros node
if(~robotics.ros.internal.Global.isNodeActive)
    launchMaster;
end

fileID = fopen('estimation.txt','w');

% Subscribers
imuDataSubscriber = rossubscriber('/mavros/imu/data');
lidarDataSubscriber = rossubscriber('/mavros/distance_sensor/hrlv_ez4_pub');
vioDataSubscriber = rossubscriber('/mavros/vision_pose/pose');

% Publishers 
stateEstimatePublisher = rospublisher('/stateEstimate', 'terpcopter_msgs/stateEstimate');

pause(2)
stateMsg = rosmessage(stateEstimatePublisher);
%stateMsg.Range = 0.2;
t0 = []; 

%KF parameters
stateKF = [0;0;0;0];
previous_t = -1;
biasAx = 4.44749;
biasAy = -8.60974;
biasAz = 1.06455;

% ROS freq rate
r = rosrate(30);
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

% Receive Latest Imu and Lidar data
imuMsg = imuDataSubscriber.LatestMessage;
lidarMsg = lidarDataSubscriber.LatestMessage;
vioMsg = vioDataSubscriber.LatestMessage;

if isempty(imuMsg) 
    state = NaN;
    disp('No imu data\n');
    fclose(fileID);
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
inertial_yaw_initial = state.psi_inertial;

if isempty(vioMsg)
    disp('Not getting VIO information'); 
end

while(1)
    % Receive Latest Imu and Lidar data
    imuMsg = imuDataSubscriber.LatestMessage;
    lidarMsg = lidarDataSubscriber.LatestMessage;
    vioMsg = vioDataSubscriber.LatestMessage;
    
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

    state.psi_inertial = round(state.psi_inertial,1);
    
    %get relative yaw = - inertial yaw_intial - inertial yaw 
    if isempty(inertial_yaw_initial), inertial_yaw_initial = state.psi_inertial; end
     state.psi_relative = -state.psi_inertial + inertial_yaw_initial;
%     disp('intial yaw');
%     disp(inertial_yaw_initial);
%     disp('relative yaw');
%     disp(state.psi_relative);

    %rounding off angles to 1 decimal place
    state.psi_inertial = round(state.psi_inertial,1);
    state.psi_relative = round(state.psi_relative,1);
    state.theta = round(state.theta,1);
    state.phi = round(state.phi,1);

    %yaw lies between [-180 +180];
    if state.psi_relative> 180, state.psi_relative = state.psi_relative-360;
    elseif state.psi_relative<-180, state.psi_relative = 360+state.psi_relative;end

    % timestamp
    ti= rostime('now');
    abs_t = eval([int2str(ti.Sec) '.' ...
        int2str(ti.Nsec)]);
   
    if isempty(t0), t0 = abs_t; end
    t = abs_t-t0;
    stateMsg.Time = t;
    
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
    
    %% Apply KF here 
    % convert IMU acceleration to world cord [NWU Frame].
    linaccIMU(1,1) = round(imuMsg.LinearAcceleration.X,3);
    linaccIMU(2,1) = round(imuMsg.LinearAcceleration.Y,3);
    linaccIMU(3,1) = round(imuMsg.LinearAcceleration.Z,3);
    
    R_imu2inert = (rotationMatrixYPR(state.psi_inertial,stateMsg.Pitch,stateMsg.Roll))';
    %R_imu2inert = (rotationMatrixYPR(pi,pi+stateMsg.Pitch,stateMsg.Roll))';

    linAcc = R_imu2inert * [linaccIMU(1,1); linaccIMU(2,1); linaccIMU(3,1)];
    %param.u = [linAcc(1); linAcc(2); linAcc(3) - 9.81];
    ax = linAcc(1) - biasAx; ay =  linAcc(2) - biasAy; az = linAcc(3) - biasAz;
    
    param.u = [linaccIMU(1,1); linaccIMU(2,1)]; %sending IMU frame acceleration
    
    % Get (WEST) East-> x and North->y from VIO topic 
    stateMsg.East = vioMsg.Pose.Position.X; % TODO: change this to west
    stateMsg.North = vioMsg.Pose.Position.Y;
    
    [predictX, predictY, stateKF, param, previous_t] = kalmanFilter(stateMsg.Time,stateMsg.East,stateMsg.North, stateKF, param, previous_t);
    
%     predictX
%     predictY
    
    % fixed loop pause
    waitfor(r);
    
    % publish stateEstimate
    send(stateEstimatePublisher, stateMsg);
    
    % [time ax ay az imuaccx imuaccY imuaccZ VIox VIoY predX predY vx vy]
    fprintf(fileID,'%5f %5f %5f %5f %5f %5f %5f %5f %5f %5f %5f %5f %5f \n', ...
        stateMsg.Time,ax,...
        ay,az,imuMsg.LinearAcceleration.X, ...
        imuMsg.LinearAcceleration.Y, imuMsg.LinearAcceleration.Z , ...
        stateMsg.East, stateMsg.North, predictX, predictY, stateKF(3), stateKF(4));

end

