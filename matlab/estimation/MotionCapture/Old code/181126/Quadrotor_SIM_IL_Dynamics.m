%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Will Craig
% CDCL Research
% 11/06/18
%
% This runs a full SE3 simulation of a quadrotor in free-flight
%
% Meant to interface with the motion capture code for testing, so
% parameters etc are built in, and it only takes the transmitter inputs
%
% Scaling Rotor speed (divide all inputs by 2000)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [t_out, position, velocity, angle, Rmat, omega_rate, R_d_old, Quat, IDs] = ...
    Quadrotor_SIM_IL_Dynamics(TxInput,IL_tspan,pos0,vel0,Rmat0,omega_rate0, R_d_old, paramQuad, K_in)


throttle_trainer = str2double(TxInput(2:5));
roll_trainer = str2double(TxInput(6:9));
pitch_trainer = str2double(TxInput(10:13));
yaw_trainer = str2double(TxInput(14:17));

throttle_PWM = floor(((throttle_trainer - 5000)/10) + 1500);
roll_PWM = floor(((roll_trainer - 5000)/10) + 1500);
pitch_PWM = floor(((pitch_trainer - 5000)/10) + 1500);
yaw_PWM = floor(((yaw_trainer - 5000)/10) + 1500);
% PWM = [throttle_PWM; roll_PWM; pitch_PWM; yaw_PWM];

u_stick = [((throttle_PWM - 1500)/400);
           ((roll_PWM - 1500)/(-400));
           ((pitch_PWM - 1500)/400);
           ((yaw_PWM - 1500)/400)];

u_max = paramQuad.u_max;
Eb3_in = u_max*[u_stick(3); u_stick(2); (u_stick(1)+1)/2];
fprintf('b3_in_sim = %2.3f, %2.3f, %2.3f\n', Eb3_in(1), Eb3_in(2), Eb3_in(3))

dt = 0.02/5; % timestep for solver, plot % 0.08 seems to match real time
            % so that's what I have the moving plot set to
tspan = IL_tspan(1):dt:IL_tspan(2);%24.4;

% INITIAL VALUES
X_0 = [pos0; vel0];

%%%%%%%%

options = odeset('RelTol',1e-6,'MaxStep',dt);

omg0 = omega_rate0;




z0 = [Rmat0(:,1); Rmat0(:,2); Rmat0(:,3); omg0; X_0];
N = length(tspan);
z = zeros(N,18);
z(1,1:18) = z0.';
t = zeros(N,1);
zdot = zeros(size(z.'));
M_B = zeros(3,N);
OMGA = zeros(3,N);
input_T = zeros(4,N);
R_d = repmat(eye(3,3),1,1,N);
R_B = repmat(eye(3,3),1,1,N);

for ii = 1:(N-1)
    [time,z_indiv] = ode45(@eom, tspan(ii:ii+1), z0, options,...
                                    R_d_old,dt,Eb3_in,K_in,u_stick);

    t(ii+1) = time(end);
    z(ii+1,1:18) = z_indiv(end,1:18);

    z0 = z_indiv(end,1:18);
    
    [zdot(:,ii+1), M_B(:,ii+1), OMGA(:,ii+1), input_T(:,ii+1), R_d(:,:,ii+1), R_B(:,:,ii+1)]...
        = eom(time(end),z0,R_d_old,dt,Eb3_in,K_in,u_stick);

    R_d_old = R_d(:,:,ii);

end

% Output back to OL
position = z(end,13:15).';
velocity = z(end,16:18).';
R_d_old = R_d(:,:,end);
Rmat = R_B(:,:,end);%[z(1:3),z(4:6),z(7:9)]
theta_ang = -asin(Rmat(3,1));
phi_ang = atan2(Rmat(3,2),Rmat(3,3));
psi_ang = atan2(Rmat(2,1),Rmat(1,1));
angle = [phi_ang, theta_ang, psi_ang].';
theta_ang_d = -asin(R_d_old(3,1));
phi_ang_d = atan2(R_d_old(3,2),R_d_old(3,3));
psi_ang_d = atan2(R_d_old(2,1),R_d_old(1,1));
% angle_err = [phi_ang_d, theta_ang_d, psi_ang_d].' - angle
omega_rate = OMGA(:,end);
% sum(input_T(:,end))
t_out = t(end);

Quat = [];
IDs = [];
end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [zdot, M_B, OMGA, T, R_d, R_B] = eom(t, z,R_d_old,dt,Eb3_in,K_in,u_stick)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     Vehicle Parameters
% % % Larger 250 size vehicle
Cd_frame = 0.8; %(from wikipedia drag coefficient table)
D = (5*2.54)*1/100;% rotor diameter [m] 
R = D/2; % [m], main rotor radius
c = 1.5/100; % Main blade chord [m]D/10; % Main blade chord [m]
m_r = 0.0027; %0.0016; % [kg], measured
m_b = m_r/2; % [kg], mass of one blade
m_m = 0.03;%0.016; % [kg], mass of motor: measured
ell = 0.21;
d = 0.02;
cm = 0.0085;% tz(1,:)./(9.81*fz(1,:)) Relation of thrust produced to torque
m_l = 0.03;% 1.75*0.136*ell; % [kg], mass of rod, maker beam has mass 0.136g/mm
%    Adjusted for QAV210 mass calculation
I1 = m_l*ell^2/12 + 2*m_m*ell^2;
I2 = m_l*ell^2/12 + 2*m_m*ell^2;
I3 = m_l*ell^2/6 + 4*m_m*ell^2;
I = diag([I1;I2;I3]);
invI = diag([1/I1;1/I2;1/I3]);
mass = 0.510; %[kg] with battery and motion caputure markers

Nb = 2; % [] Number of blades per rotor
e = 0.1; % [] hinge offset (percent of R; e' from derivation pages) From Hoffmann
k_beta = 3; %.23% [N*m/rad] blade spring constant % 113330 for BO-105
Ib = (m_b)*(R^3-(e*R)^3)/(3*R); % [kg*m^2] Blade moment of inertia Integrate from e to R
Cla = 2*pi; % lift curve slope
rho = 1.225; %[kg/m^3]
Lock = rho*Cla*c*R^4/Ib;

th0 = 0.28;%0.14;%0.1575;%0.24;%0.24; % Root angle of attack
th_tw = 0.165-th0;%0.10-th0;%(0.19-th0); % Blade linear twist

% To find nu_beta
rpm =  12000;
Omega   = rpm*2*pi/60; % [rad/s] % For gemfan
% h = m_r*D^2/12*Omega; % angular momentum of blades (I guess we ignore h of motor)
w_B     = sqrt(k_beta/Ib); % Blade natural frequency (omega_beta_0 in HeliAero notes)
nu_beta = sqrt(1 + (3/2)*(e/(1-e)) + w_B^2/Omega^2); % Formula from HeliAero, 
    % with further accuracy from derivation pages
    
% zeta = (gamma/(16*nu_beta))*(1-(8*e/3)+2*e^2-e^4/3);
% w_n  = Omega*nu_beta; % natural frequency of blade flapping (from eqns)

lam  = 0.075;%0.11; % Inflow ratio %0.08 is max, gets down to 0.05 or 0.03 at high gust
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Max thrust sum
u_max = 12;
    
% Earth parameters
g = 9.81; %[m/s] gravity

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


z = z(:);
p = z(10);
q = z(11);
r = z(12);
% X = [z(13); z(14); z(15)];
V = [z(16); z(17); z(18)];
OMGA = [p;q;r];
% skw_OMGA = skew(OMGA);
skw_OMGA = [ 0,  -r,   q; 
             r,   0,  -p; 
            -q,   p,   0];

% % Desired values, taken from Lee CDC 2010
% X_d = 0;%0*[0.4*t; 0.4*sin(pi*t); 0.6*cos(pi*t)];
% X_d_dot = 0;%0*[0.4; pi*0.4*cos(pi*t); -pi*0.6*sin(pi*t)];
% X_d_ddot = 0;%0*[0; -pi^2*0.4*sin(pi*t); -pi^2*0.6*cos(pi*t)];
% % X_d_dot = [0;0;0];%diff(x_d, t); (need symbolic t for this to work)
% % X_d_ddot = [0;0;0];%diff(x_d_dot, t);

Eb1d = [1;5*u_stick(4);0]/norm([1;5*u_stick(4);0]);%[cos(pi*t); sin(pi*t); 0];%
% Eb1d = [1;0;0];%[cos(pi*t); sin(pi*t); 0];%

gust = 1e-8*[-1;0;0];%gustin*(1.0000001-cos(pi*t))/2;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FIND FORCES AND MOMENTS
% Rotations
R_B = [z(1:3),z(4:6),z(7:9)];

%%%%%%%%%% TRANSLATION IS IN INERTIAL, ROTATION IN BODY %%%%%%%%%%%%%%%%%%%
% Ee1 = [1;0;0];
% Ee2 = [0;1;0];
Ee3 = [0;0;1];
% Be1 = R_B.'*Ee1;
% Be2 = R_B.'*Ee2;    
% Be3 = R_B.'*Ee3;

% body
Bb1 = [1;0;0];
Bb2 = [0;1;0];    
Bb3 = [0;0;1];
% Eb1 = R_B*Bb1;
% Eb2 = R_B*Bb2;
Eb3 = R_B*Bb3;

    
Bvinf = R_B.'*(gust - V);% - R_B.'*V;
Bvinf12 = [Bvinf(1); Bvinf(2)]; % Vinf in plane defined by b3

% Flapping amplitude and angle
% Find V_inf in spherical
mu   = sqrt(Bvinf12.'*Bvinf12)/(Omega*R);

B0 = 0; B1s = 0; B1c = 0;
for nn = 1:10

B0 = (1/nu_beta^2)*(-Lock/8*(e - 2*e + e^3/3)*mu*B1c ...
    + Lock/8*(th0*((1 - 4*e/3 + e^4/3) + (1 - 2*e + e^2)*mu^2)...
    + th_tw*((4/5 - e + e^5/5) + (2/3 - e + e^3/3)*mu^2)...
    - lam*(4/3 - 2*e + 2*e^3/3)));

B1s = (1/(nu_beta^2-1))*(-Lock/8*(-(1 - 8*e/3 + 2*e^2 - e^4/3)...
    + (1 - 2*e + e^2)*mu^2)*B1c ...
    + Lock/8*(th0*(8/3 - 4*e + 4*e^3/3)*mu ...
    + th_tw*(2-8*e/3 + 2*e^4/3)*mu ...
    - lam*(2 - 4*e + 2*e^2)*mu));

B1c = (1/(nu_beta^2-1))*(-Lock/8*((1 - 8*e/3 + 2*e^2 - e^4/3)...
    + (1 - 2*e + e^2)*mu^2)*B1s ...
    - Lock/8*(4/3 - 2*e + 2*e^3/3)*mu*B0...
    - Lock/8*lam*(15*pi/23)*tan(atan(mu/lam)/2)*(1 - 4*e/3 + e^4/3));%*(1-exp(-2*t))
end
Beta = sqrt(B1c^2 + B1s^2);
phi_D = atan2(B1s,B1c)-pi/2;
% return
phiBE = atan2(lam, 0.75);
blade_aoa = (th0 + 0.75*th_tw) - phiBE;

% Wind frames
u1 = [Bvinf12/sqrt(Bvinf12.'*Bvinf12);0];
u2 = cross([0;0;1],u1);
R_b2u = [u1, u2,[0;0;1]];

R_u2vp = [cos(phi_D) -sin(phi_D), 0; sin(phi_D) cos(phi_D), 0; 0, 0, 1];
R_b2vp = R_b2u*R_u2vp;
v1p = R_b2vp(:,1);
v2p = R_b2vp(:,2);

R_u2vm = [cos(-phi_D) -sin(-phi_D), 0; sin(-phi_D) cos(-phi_D), 0; 0, 0, 1];
R_b2vm = R_b2u*R_u2vm;
v1m = R_b2vm(:,1);
v2m = R_b2vm(:,2);


%%%%%%%%%%%%%%%%%%%%%%%%% COMPLETE OUTER LOOP %%%%%%%%%%%%%%%%%%%%%%%%%%%%
F_D = (4*Nb*0.5*rho*((1/2)*Omega*R^2*sqrt(Bvinf12.'*Bvinf12)) ...
    *c*Cla*(blade_aoa)*sin(phiBE)*(R_B*u1)...
    + (1/2)*rho*sqrt(Bvinf.'*Bvinf)*(R_B*Bvinf)*Cd_frame*(0.2*0.2));
% I don't know where the 0.2 came from; it's the drag frontal area term but
% I don't know why that was chosen

% c subscripting follows Lee's work, represents "computed"
Eb3_c = ((Eb3_in - F_D)...
        /norm(Eb3_in - F_D));
Eb2_c = cross(Eb3_c,Eb1d)/norm(cross(Eb3_c,Eb1d));
Eb1_c = cross(Eb2_c,Eb3_c);

R_d = [Eb1_c, Eb2_c, Eb3_c];

R_d_dot = (R_d - R_d_old)/(dt);%zeros(3); %
% R_d
% R_d_old

OMGA_d = vee(R_d.'*R_d_dot);

%%%%%%%%%%%%%%%%%%%%%%%%% SOLVE FOR ERRORS %%%%%%%%%%%%%%%%%%%%%%%%%%%%
e_r = 1/2*vee(R_d.'*R_B - R_B.'*R_d); %*sqrt(1+trace(R_d.'*R))) from Systems and control letters
e_omg = OMGA - R_B.'*R_d*OMGA_d;
%%%%%%%%%%%%%%%%%%%%%%%%%%% CONTROL LAW %%%%%%%%%%%%%%%%%%%%%%%%%%
% (Eb3_in - F_D)
% Eb3
Thrust = (Eb3_in - F_D).'*(Eb3); % Total thrust from all rotors
% Thrust = (Eb3_in - F_D).'*(Eb3_in - F_D); % Total thrust from all rotors
% For some reason the QAC work uses individual thrust at each rotor, so
% just be careful that we avoid using that "terminology"

Tmax = 3;%1.3*1466; rpm to rad/s
Tmin = 0.05;
%%%%%%%%%%%%%%%%% FEEDBACK LINEARIZATION THRUST AS INPUT %%%%%%%%%%%%%%%%%
% Using V frame calculations rather than u2*sin(phi_D).'*b_i
% Bvinf3 = Bvinf(3);
v1pb1 = v1p.'*Bb1;
v1mb1 = v1m.'*Bb1;
v1pb2 = v1p.'*Bb2;
v1mb2 = v1m.'*Bb2;

% Aerodynamic Moment with hinge offset
% M_aero = [Nb/2*(k_beta*Beta + m_b*R^2*Omega^2*e*(1/2-e^2/2)*sin(Beta))*(2*v1pb1 - 2*v1mb1);
%     Nb/2*(k_beta*Beta + m_b*R^2*Omega^2*e*(1/2-e^2/2)*sin(Beta))*(2*v1pb2 - 2*v1mb2);
%     0];
% % Without hinge offset (2 props in each direction, end up adding
M_aero = [Nb/2*(k_beta*Beta)*(2*v1pb1 - 2*v1mb1);
    Nb/2*(k_beta*Beta)*(2*v1pb2 - 2*v1mb2);
    0];

invDelta = diag([(2*I1)/ell; (2*I2)/ell; I3/cm]);

% w/o hinge offset
% with hinge offset
b_claw = invI*(-skw_OMGA*(I*OMGA) + 0*M_aero);

Kr = K_in(3);%50;%0.5;%6;
Komg = K_in(4);%Kr/10;%0.1;%0.5;
ups = [38.2/38.2*(-Kr*e_r(1) - Komg*e_omg(1));% - Ki*int_e_r(1));
       38.2/38.2*(-Kr*e_r(2) - Komg*e_omg(2));% - Ki*int_e_r(2));
       1.54/38.2*(-Kr*e_r(3) - Komg*e_omg(3))];% - Ki*int_e_r(3))];


% Fanciness in order to maintain control direction during saturation
% Math comes from using the inputs' relationship to each individual thrust.
% We assume that we can multiply the stabilizing input "u" by an additional
% gain, Kmod, and so that's what we're solving for. From my TCST paper, 
% start with definition of T1 from nu's and T0 (abuse of notation here), 
% then set lower and upper bound on T1 as Tmin and Tmax, subtract T0 from 
% both sides, subtract linearization from both sides, then multiply
% stabilizing terms by Kmod, then divide by the stabilizing term and set 
% Kmod equal to both sides. One will be positive and one negative; in a
% case with a solution the positive side is the correct one.

%{k
nu_b = (invDelta*(-b_claw));
nu_ups = invDelta*(ups);
T0 = Thrust/4-Tmin;
T1 = Tmax - Thrust/4;

Kcheck(:,1:2) = [(-4*T0 - (-nu_b(1) + nu_b(2) + nu_b(3))),...
                 ( 4*T1 - (-nu_b(1) + nu_b(2) + nu_b(3)));
                (-4*T0 - (-nu_b(1) - nu_b(2) - nu_b(3))),...
                 ( 4*T1 - (-nu_b(1) - nu_b(2) - nu_b(3)));
                (-4*T0 - ( nu_b(1) + nu_b(2) - nu_b(3))),...
                 ( 4*T1 - ( nu_b(1) + nu_b(2) - nu_b(3)));
                (-4*T0 - ( nu_b(1) - nu_b(2) + nu_b(3))),...
                 ( 4*T1 - ( nu_b(1) - nu_b(2) + nu_b(3)))];
Kmods(:,1:2) = [Kcheck(1,1:2)/(-nu_ups(1) + nu_ups(2) + nu_ups(3));
                Kcheck(2,1:2)/(-nu_ups(1) - nu_ups(2) - nu_ups(3));
                Kcheck(3,1:2)/( nu_ups(1) + nu_ups(2) - nu_ups(3));
                Kcheck(4,1:2)/( nu_ups(1) - nu_ups(2) + nu_ups(3))];

     for ii = 1:4
        Kmods(ii,3) = max(Kmods(ii,1:2));
            % check positive or negative of initial inequality - left side
            % should be < 0 and right side should be > 0 for a solution to
            % exist. Then when dividing by the ups terms one of the signs 
            % should be positive to yield the Kmods terms
            if Kcheck(ii,1) > 0 || Kcheck(ii,2) < 0
                Kmods(ii,3) = 0;
            end
     end
 
Kmod = min([Kmods(:,3);1]);
% disp(Kmods)
nu_ups = Kmod*nu_ups;
nu = nu_b+nu_ups;
%}
% nu = (invDelta*(ups - b_claw)); % Without Kmod



% nu_noIL = (invDelta*(-b_claw));
% fprintf('With IL Gains: %2.3f %2.3f %2.3f \nWithout %2.3f %2.3f %2.3f \n',...
%     nu(1), nu(2), nu(3), nu_noIL(1), nu_noIL(2), nu_noIL(3))
% nu
% return
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% THRUST %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% T_i in N
% T(1) = (Thrust/4 + 1/4*(-nu(1) + nu(2) + nu(3)));
% T(2) = (Thrust/4 + 1/4*(-nu(1) - nu(2) - nu(3)));
% T(3) = (Thrust/4 + 1/4*( nu(1) + nu(2) - nu(3)));
% T(4) = (Thrust/4 + 1/4*( nu(1) - nu(2) + nu(3)));

T = Thrust/4 + [1/4*(-nu(1) + nu(2) + nu(3));
                1/4*(-nu(1) - nu(2) - nu(3));
                1/4*( nu(1) + nu(2) - nu(3));
                1/4*( nu(1) - nu(2) + nu(3))];
%%%%%%%%%%%%%%%%%%% SCALING %%%%%%%%%%%%%%%%%%%%%%%%
% Tmax = 3;%1.3*1466; rpm to rad/s
for mm = 1:4
    T(mm) = min(T(mm),Tmax);
    T(mm) = max(T(mm),Tmin);
end

Thrust = (T(1)+T(2)+T(3)+T(4));

%%%%%%%%%%%%%%%%%%%%%%%%%% FORCES AND MOMENTS %%%%%%%%%%%%%%%%%%%%%%%%
% Assuming average thrust and angular speed
F_flap_p = Thrust/4*sin(Beta)*v2p ...
...    + F2u1*u1 + F2u2p*u2;
    + Nb*0.5*rho*((1/2)*Omega*R^2*sqrt(Bvinf12.'*Bvinf12)) ...
    *c*Cla*(blade_aoa)*sin(phiBE)*u1;

F_flap_m = Thrust/4*sin(Beta)*(-v2m) ...
...    + F2u1*u1 + F2u2m*u2;
    + Nb*0.5*rho*((1/2)*Omega*R^2*sqrt(Bvinf12.'*Bvinf12)) ...
    *c*Cla*(blade_aoa)*sin(phiBE)*u1;

% In body frame
F_D_frame = (1/2)*rho*sqrt(Bvinf.'*Bvinf)*Bvinf*Cd_frame*(0.2*0.2);
% fprintf('Velocity is %2.4f %2.4f %2.4f\n', V(1), V(2), V(3))
% disp(R_B*F_D_frame)
% 1/2 rho v^2 cd A

% In body frame
F_B = 2*F_flap_p + 2*F_flap_m + F_D_frame;

M_flap_p = Nb*(1/2)*(k_beta*Beta + m_b*R^2*Omega^2*e*(1/2-e^2/2)*sin(Beta))*(v1p);% + M1*(-u2);

M_flap_m = Nb*(1/2)*(k_beta*Beta + m_b*R^2*Omega^2*e*(1/2-e^2/2)*sin(Beta))*(-v1m);% + M1*(-u2);

% M_B = cross(([0;0;d]),(2*F_flap_p + 2*F_flap_m))...
%     + (2*M_flap_p + 2*M_flap_m)...
%     + cross(([ell/2;0;0]),[0;0;T(1)]) + cross(([-ell/2;0;0]),[0;0;T(2)])...
%     + cross(([0;ell/2;0]),[0;0;T(3)]) + cross(([0;-ell/2;0]),[0;0;T(4)])...
%     - cm*(T(1)+T(2))*[0;0;1] + cm*(T(3)+T(4))*[0;0;1];

% M_B = cross(([0;0;d]),(2*F_flap_p + 2*F_flap_m))...
%     + (2*M_flap_p + 2*M_flap_m)...
%     + [0;-ell/2*T(1);0] + [0;ell/2*T(2);0]...
%     + [ell/2*T(3);0;0] + [-ell/2*T(4);0;0]...
%     - cm*(T(1)+T(2))*[0;0;1] + cm*(T(3)+T(4))*[0;0;1];

% M_B = cross([0;0;d],(2*F_flap_p + 2*F_flap_m))...
%     + (2*M_flap_p + 2*M_flap_m)... 
%     + cross([-ell*sqrt(2)/4;-ell*sqrt(2)/4;0],[0;0;T(1)])...
%     + cross([ ell*sqrt(2)/4;-ell*sqrt(2)/4;0],[0;0;T(2)])...
%     + cross([-ell*sqrt(2)/4; ell*sqrt(2)/4;0],[0;0;T(3)])...
%     + cross([ ell*sqrt(2)/4; ell*sqrt(2)/4;0],[0;0;T(4)])...
%     + cm*(T(1)-T(2)-T(3)+T(4))*[0;0;1];

M_B = cross([0;0;d],(2*F_flap_p + 2*F_flap_m))...
    + (2*M_flap_p + 2*M_flap_m)... 
    + [-ell*sqrt(2)/4;  ell*sqrt(2)/4; 0]*T(1)...
    + [-ell*sqrt(2)/4; -ell*sqrt(2)/4; 0]*T(2)...
    + [ ell*sqrt(2)/4;  ell*sqrt(2)/4; 0]*T(3)...
    + [ ell*sqrt(2)/4; -ell*sqrt(2)/4; 0]*T(4)...
    + cm*(T(1)-T(2)-T(3)+T(4))*[0;0;1];

Rdot = R_B*skw_OMGA;
zdot(1:3,1) = Rdot(:,1);
zdot(4:6,1) = Rdot(:,2);
zdot(7:9,1) = Rdot(:,3);
zdot(10:12,1) = [1/I1*((I2-I3)*q*r + M_B(1));
                 1/I2*((I3-I1)*r*p + M_B(2));
                 1/I3*((I1-I2)*p*q + M_B(3))];
zdot(13:15,1) = V;
zdot(16:18,1) = 1/mass*(-mass*g*Ee3 + Thrust*Eb3 + (R_B*F_B));
% -mass*g*Ee3 + Thrust*Eb3
% Thrust*Eb3

end

