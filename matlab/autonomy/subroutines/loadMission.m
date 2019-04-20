function mission = loadMission()
mission.config.firstLoop = 1;

% for reference:
%
% ayprCmdMsg = rosmessage(ayprCmdPublisher);
% ayprCmdMsg.AltDesiredMeters = 0;
% ayprCmdMsg.YawDesiredDeg = 0;
% ayprCmdMsg.PitchDesiredDeg = 0;
% ayprCmdMsg.RollDesiredDeg = 0;
% ayprCmdMsg.AltSwitch = 0;
% ayprCmdMsg.YawSwitch = 0;
% ayprCmdMsg.PitchSwitch = 0;
% ayprCmdMsg.RollSwitch = 0;

i = 1;
% Behavior 1: Takeoff
mission.bhv{i}.name = 'bhv_takeoff';
mission.bhv{i}.ayprCmd = default_aypr_msg(ayprCmdPublisher);
mission.bhv{i}.ayprCmd.AltSwitch = 1; 
mission.bhv{i}.ayprCmd.AltDesiredMeters = 1; 
mission.bhv{i}.thresholdDist = 0.1;
mission.bhv{i}.completion.status = false;

i = i + 1;
% Behavior 2: Hover in Place
mission.bhv{i}.name = 'bhv_hover';
mission.bhv{i}.ayprCmd = default_aypr_msg(ayprCmdPublisher);
mission.bhv{i}.ayprCmd.AltSwitch = 1; 
mission.bhv{i}.ayprCmd.AltDesiredMeters = 1; 
mission.bhv{i}.completion.durationSec = 9.95; % 10 seconds
mission.bhv{i}.completion.status = false;     % completion flag

% i = i + 1;
% % Behavior 3: Point to Direction 
% mission.bhv{i}.name = 'bhv_point_to_target';
% mission.bhv{i}.ahs.desiredAltMeters = 1;
% mission.bhv{i}.ahs.desiredYawDegrees = 0;
% mission.bhv{i}.completion.durationSec = 9.95; % 10 seconds
% mission.bhv{i}.completion.status = false;     

i = i + 1;
% Behavior 4: Land
mission.bhv{i}.name = 'bhv_land';
mission.bhv{i}.ayprCmd = default_aypr_msg(ayprCmdPublisher);
mission.bhv{i}.ayprCmd.AltSwitch = 1; 
mission.bhv{i}.ayprCmd.AltDesiredMeters = 0.2; 
mission.bhv{i}.completion.threshold = 0.1;
mission.bhv{i}.completion.status = false;

end