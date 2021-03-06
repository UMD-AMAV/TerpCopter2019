clear; close all; clc; format compact;
addpath('../')
params = loadParams();
fprintf('Launching ORB H Det...\n');

%global timestamps

% initialize ROS
if(~robotics.ros.internal.Global.isNodeActive)
    rosinit;
end

% Publishers

%fprintf('Setting up servoSwitch Publisher ...\n');
%servoSwitchCmdPublisher = rospublisher('/servoSwitch', 'terpcopter_msgs/servoSwitchCmd');

% initialize control off
imgMsg = rosmessage('sensor_msgs/CompressedImage');


% Subscribers
fprintf('Subscribing to /camera/image_raw/compressed ...\n');
cameraSubscriber = rossubscriber('/camera/image_raw/compressed');

h = figure;
g = figure;
f = figure;
p = figure;

I = rgb2gray(imread('/home/amav/amav/Terpcopter3.0/matlab/vision/H_template.jpg'));
points = detectORBFeatures(I);%,"NumOctaves",2,"MetricThreshold",1000,"NumScaleLevels",4,"ROI",[size(I,2)/4 (size(I,1)*1.1)/4 (size(I,2)*2)/4 (size(I,1)*2.5)/4]);
	[features, valid_points] = extractFeatures(I, points.selectStrongest(50),"Method","ORB","BlockSize",5,"Upright",true,"FeatureSize",128);

while (1)

	imgMsg = cameraSubscriber.LatestMessage;
	I2 = readImage(imgMsg);
	
	tic
	
	%strong_point = valid_points.selectStrongest(50);
	%strong_feature = extractFeatures(I,strong_point);
	%hold on
	points2 = detectORBFeatures(I2);%,"NumOctaves",2,"MetricThreshold",1000,"NumScaleLevels",4);
	[features2, valid_points2] = extractFeatures(I2, points2.selectStrongest(50),"Method","ORB","BlockSize",5,"Upright",true,"FeatureSize",128);
	%strong_point2 = valid_points2.selectStrongest(5);
	%strong_feature2 = extractFeatures(I,strong_point2);
	[indexPairs,matchmetric] = matchFeatures(features,features2, "Method", 'Exhaustive',"MatchThreshold",80,"MaxRatio",0.9,"Unique",true,"Metric","SSD");
	matchedPoints1 = valid_points(indexPairs(:,1));
	matchedPoints2 = valid_points2(indexPairs(:,2));

	%Display the matching points. The data still includes several outliers, but you can see the effects of rotation and scaling on the display of matched features.

	%legend('matched points 1','% matched points 2');

	[tform, inlierDistorted, inlierOriginal] = estimateGeometricTransform(...
	    matchedPoints2, matchedPoints1, 'affine');%,"Confidence",99,"MaxDistance",200);
	Tinv  = tform.invert.T;

	ss = Tinv(2,1);
	sc = Tinv(1,1);
	scaleRecovered = sqrt(ss*ss + sc*sc)
	thetaRecovered = atan2(ss,sc)*180/pi
	toc

    imshow(I,'Template',h); hold on;
	plot(valid_points,'showOrientation',true);

	imshow(I2, 'Feed',g); hold on; 
	plot(valid_points2,'showOrientation',true);

	showMatchedFeatures(I,I2,matchedPoints1,matchedPoints2,f);

	outputView = imref2d(size(I));
	recovered  = imwarp(I2,tform,'OutputView',outputView);
	imshowpair(I,recovered,'montage',p)

end
