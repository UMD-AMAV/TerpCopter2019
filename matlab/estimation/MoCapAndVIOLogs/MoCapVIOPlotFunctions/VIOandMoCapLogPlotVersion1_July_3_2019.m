% Plotting both the Realsense VIO and the Motion Capture 
clear;
close all;
clc;

% VIO Log file should be selected FIRST
[file1,path1] = uigetfile('*.log');
% Motion Capture Log file should be selected SECOND
[file2,path2] = uigetfile('*.log');

%% Realsense VIO
file1
filepath1 = [path1 file1];
data1 = csvread(filepath1);

% parse out
TimeVIO = data1(:,1);
TimeVIO = TimeVIO - TimeVIO(1);
PositionXVIO = data1(:,2);
PositionYVIO = data1(:,3);
PositionZVIO = data1(:,4);


%% Motion Capture
file2
filepath2 = [path2 file2];
data2 = csvread(filepath2);

%parse out
TimeMOCAP = data2(:,1);

PositionXMOCAP = data2(:,2);
PositionYMOCAP = data2(:,3);
PositionZMOCAP = data2(:,4);

phi = data2(:,5);
theta = data2(:,6);
psi = data2(:,7);

%% Plotting Position 
InitialOffsetX = PositionXMOCAP(1) + PositionXVIO(1)
InitialOffsetY = PositionYMOCAP(1) + PositionYVIO(1)
InitialOffsetZ = PositionZMOCAP(1) - PositionZVIO(1)

PositionXVIO_withOffset = -PositionXVIO + InitialOffsetX;
PositionYVIO_withOffset = -PositionYVIO + InitialOffsetY;
PositionZVIO_withOffset = PositionZVIO + InitialOffsetZ;

figure(1)
hold on;
plot3(PositionXMOCAP,PositionYMOCAP,PositionZMOCAP);
plot3(PositionXVIO_withOffset, PositionYVIO_withOffset, PositionZVIO_withOffset);
plot3(PositionXMOCAP(1),PositionYMOCAP(1),PositionZMOCAP(1), 'g.');
title('3D Plot of Motion Capture vs Realsense VIO Position');
xlabel('Position X (m)');
ylabel('Position Y (m)');
zlabel('Position Z (m)');
legend('Motion Capture','Realsense VIO');
set(gca, 'FontSize', 16);
grid on
hold off


figure(2)
subplot(3,1,1)
plot(TimeMOCAP,PositionXMOCAP);
hold on
plot(TimeMOCAP,PositionXVIO_withOffset);
title('Position X vs Time Comparision for Motion Capture and Realsense VIO')
xlabel('Time (seconds)');
ylabel('Position X (meters)');
legend('Motion Capture','Realsense VIO');
grid on
set(gca, 'FontSize', 12);
hold off

subplot(3,1,2)
plot(TimeMOCAP,PositionYMOCAP);
hold on
plot(TimeMOCAP,PositionYVIO_withOffset);
title('Position Y vs Time Comparision for Motion Capture and Realsense VIO')
xlabel('Time (seconds)');
ylabel('Position Y (meters)');
legend('Motion Capture','Realsense VIO');
grid on
set(gca, 'FontSize', 12);
hold off

subplot(3,1,3)
plot(TimeMOCAP,PositionZMOCAP);
hold on
plot(TimeMOCAP,PositionZVIO_withOffset);
title('Position Z vs Time Comparision for Motion Capture and Realsense VIO')
xlabel('Time (seconds)');
ylabel('Position Z (meters)');
legend('Motion Capture','Realsense VIO');
grid on
set(gca, 'FontSize', 12);
hold off


%% Calculating the Difference Between Motion Capture and Realsense VIO
DifferencePositionX = PositionXMOCAP - PositionXVIO_withOffset;
DifferencePositionY = PositionYMOCAP - PositionYVIO_withOffset;
DifferencePositionZ = PositionZMOCAP - PositionZVIO_withOffset;

figure(3)
subplot(3,1,1)
hold on
plot(TimeMOCAP,DifferencePositionX);
title('Error Difference Between Motion Capture and Realsense VIO Position X')
xlabel('Time (seconds)');
ylabel('Difference of Position X (meters)');
legend('MoCap Position X - VIO Position X');
grid on
set(gca, 'FontSize', 12);
hold off

subplot(3,1,2)
hold on
plot(TimeMOCAP,DifferencePositionY);
title('Error Difference Between Motion Capture and Realsense VIO Position Y')
xlabel('Time (seconds)');
ylabel('Difference of Position Y (meters)');
legend('MoCap Position Y - VIO Position Y');
grid on
set(gca, 'FontSize', 12);
hold off

subplot(3,1,3)
hold on
plot(TimeMOCAP,DifferencePositionZ);
title('Error Difference Between Motion Capture and Realsense VIO Position Z')
xlabel('Time (seconds)');
ylabel('Difference of Position Z (meters)');
legend('MoCap Position Z - VIO Position Z');
grid on
set(gca, 'FontSize', 12);
hold off


%% Plotting Velocity from Differentiated Position X Y Z
DifferentiatedVelocityXMOCAP = gradient(PositionXMOCAP(:)) ./ gradient(TimeMOCAP(:));
DifferentiatedVelocityYMOCAP = gradient(PositionYMOCAP(:)) ./ gradient(TimeMOCAP(:));
DifferentiatedVelocityZMOCAP = gradient(PositionZMOCAP(:)) ./ gradient(TimeMOCAP(:));

DifferentiatedVelocityXVIO = gradient(PositionXVIO_withOffset(:)) ./ gradient(TimeMOCAP(:));
DifferentiatedVelocityYVIO = gradient(PositionYVIO_withOffset(:)) ./ gradient(TimeMOCAP(:));
DifferentiatedVelocityZVIO = gradient(PositionZVIO_withOffset(:)) ./ gradient(TimeMOCAP(:));

figure(4)
subplot(3,1,1)
hold on
plot(TimeMOCAP, DifferentiatedVelocityXMOCAP);
plot(TimeMOCAP, DifferentiatedVelocityXVIO);
title('Linear Velocity X vs Time Comparision for Motion Capture and Realsense VIO');
xlabel('Time (seconds)');
ylabel('Velocity X (meters/second)');
legend('Motion Capture','Realsense VIO');
grid on
set(gca, 'FontSize', 12);
hold off

subplot(3,1,2)
hold on
plot(TimeMOCAP, DifferentiatedVelocityYMOCAP);
plot(TimeMOCAP, DifferentiatedVelocityYVIO);
title('Linear Velocity Y vs Time Comparision for Motion Capture and Realsense VIO');
xlabel('Time (seconds)');
ylabel('Velocity Y (meters/second)');
legend('Differentiated Motion Capture','Differentiated Realsense VIO', 'Velocity of Realsense VIO from Odom');
grid on
set(gca, 'FontSize', 12);
hold off

subplot(3,1,3)
hold on
plot(TimeMOCAP, DifferentiatedVelocityZMOCAP);
plot(TimeMOCAP, DifferentiatedVelocityZVIO);
title('Linear Velocity Z vs Time Comparision for Motion Capture and Realsense VIO');
xlabel('Time (seconds)');
ylabel('Velocity Z (meters/second)');
legend('Motion Capture','Realsense VIO');
grid on
set(gca, 'FontSize', 12);
hold off
