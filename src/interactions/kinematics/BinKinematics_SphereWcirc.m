%% BinKinematics_SphereWcirc class
%
%% Description
%
% This is a sub-class of the <BinKinematics.html BinKinematics> class for
% the implementation of the *Sphere-Wall Circle* binary kinematics for
% particle-wall interactions of types
% <Particle_Sphere.html Particle Sphere> and
% <Wall_Circle.html Wall Circle>.
%
classdef BinKinematics_SphereWcirc < BinKinematics
    %% Public properties
    properties (SetAccess = public, GetAccess = public)
        inside logical = logical.empty;   % flag for particle inside the circular wall
    end
    
    %% Constructor method
    methods
        function this = BinKinematics_SphereWcirc()
            this = this@BinKinematics(BinKinematics.PARTICLE_WALL,BinKinematics.SPHERE_WALL_CIRCLE);
        end
    end
    
    %% Public methods: implementation of super-class declarations
    methods
        %------------------------------------------------------------------
        function setEffParams(~,int)
            p  = int.elem1;  w  = int.elem2;
            mp = p.material; mw = w.material;
            
            % Assumption: effective radius and mass consider particle only
            int.eff_radius = p.radius;
            int.eff_mass   = p.mass;
            
            % Wall with no material
            % Assumption: effective and average properties are the particle values
            if (isempty(mw))
                if (~isempty(mp.young) && ~isempty(mp.poisson))
                    int.eff_young = mp.young / (1 - mp.poisson^2);
                    if (~isempty(mp.young0))
                        int.eff_young0 = mp.young0 / (1 - mp.poisson^2);
                    end
                end
                if (~isempty(mp.shear) && ~isempty(mp.poisson))
                    int.eff_shear = mp.shear / (2 - mp.poisson);
                end
                if (~isempty(mp.poisson))
                    int.avg_poisson = mp.poisson;
                end
                if (~isempty(mp.conduct))
                    int.eff_conduct = mp.conduct/2;
                    int.avg_conduct = mp.conduct;
                end
                
            % Wall with material
            else
                if (~isempty(mp.young) && ~isempty(mp.poisson) && ~isempty(mw.young) && ~isempty(mw.poisson))
                    int.eff_young = 1 / ((1-mp.poisson^2)/mp.young + (1-mw.poisson^2)/mw.young);
                    if (~isempty(mp.young0) && ~isempty(mw.young0))
                        int.eff_young0 = 1 / ((1-mp.poisson^2)/mp.young0 + (1-mw.poisson^2)/mw.young0);
                    end
                end
                if (~isempty(mp.shear) && ~isempty(mp.poisson) && ~isempty(mw.shear) && ~isempty(mw.poisson))
                    int.eff_shear = 1 / ((2-mp.poisson)/mp.shear + (2-mw.poisson)/mw.shear);
                end
                if (~isempty(mp.poisson) && ~isempty(mw.poisson))
                    int.avg_poisson = (mp.poisson + mw.poisson) / 2;
                end
                if (~isempty(mp.conduct) && ~isempty(mw.conduct))
                    int.eff_conduct = mp.conduct * mw.conduct / (mp.conduct + mw.conduct);
                    int.avg_conduct = mp.conduct; % assumption: average conductivity considers particle only
                end
            end
        end
        
        %------------------------------------------------------------------
        function this = setRelPos(this,p,w)
            % Set distance and surface separation
            direction = p.coord - w.center;
            d = norm(direction);
            if (d <= w.radius) % Particle inside circle
                this.inside = true;
                this.dir    = direction;
                this.separ  = w.radius - d - p.radius;
                this.dist   = p.radius + this.separ;
                this.distc  = this.dist;
            else % Particle outside circle
                this.inside = false;
                this.dir    = -direction;
                this.separ  = d - w.radius - p.radius;
                this.dist   = p.radius + this.separ;
                this.distc  = this.dist;
            end
        end
        
        %------------------------------------------------------------------
        function this = setOverlaps(this,int,dt)
            p = int.elem1; w = int.elem2;
            
            % Normal overlap and unit vector
            this.ovlp_n = -this.separ;
            this.dir_n  =  this.dir / norm(this.dir);
            
            % Positions of contact point
            % Assumption: discount the full overlap from particle
            cp = (p.radius - this.ovlp_n) * this.dir_n;
            if (this.inside)
                cw = w.radius * this.dir_n;
            else
                cw = -w.radius * this.dir_n;
            end
            
            % Particle velocity at contact point (3D due to cross-product)
            wp  = cross([0;0;p.veloc_rot],[cp(1);cp(2);0]);
            vcp = p.veloc_trl + wp(1:2);
            
            % Wall velocity at contact point (3D due to cross-product)
            ww  = cross([0;0;w.veloc_rot],[cw(1);cw(2);0]);
            vcw = w.veloc_trl + ww(1:2);
            
            % Relative velocities
            % Assumption: rotation and angular velocities consider the particle only
            this.vel_trl = vcp - vcw;
            this.vel_rot = wp(1:2);       % particle only
            this.vel_ang = p.veloc_rot;   % particle only
            
            % Normal overlap rate of change
            this.vel_n = dot(this.vel_trl,this.dir_n);
            
            % Tangential relative velocity
            vt = this.vel_trl - this.vel_n * this.dir_n;
            
            % Tangential unit vector
            if (any(vt))
                this.dir_t = vt / norm(vt);
            else
                this.dir_t = [0;0];
            end
            
            % Tangential overlap rate of change
            this.vel_t = dot(this.vel_trl,this.dir_t);
            
            % Tangential overlap
            if (isempty(this.ovlp_t))
                this.ovlp_t = this.vel_t * dt;
            else
                this.ovlp_t = this.ovlp_t + this.vel_t * dt;
            end
        end
        
        %------------------------------------------------------------------
        function this = setContactArea(this,int)
            % Needed properties
            d    = norm(this.dir);
            r1   = int.elem1.radius;
            r2   = int.elem2.radius;
            r1_2 = r1 * r1;
            r2_2 = r2 * r2;
            
            % Contact radius
            this.contact_radius = sqrt(r1_2-((r1_2-r2_2+d^2)/(2*d))^2);
            
            % Contact correction
            if (~isempty(int.corarea))
                % Adjusted radius
                int.corarea.fixRadius(int);
                
                % Adjusted distance consistent with adjusted radius
                if (this.inside)
                    this.distc = r2 - sqrt(r2_2-this.contact_radius^2) + sqrt(r1_2-this.contact_radius^2);
                else
                    this.distc = sqrt(r1_2-this.contact_radius^2) + sqrt(r2_2-this.contact_radius^2) - r2;
                end
            end
        end
        
        %------------------------------------------------------------------
        function this = setVoronoiEdge(this,~,int)
            % Assumption: same as the particle diameter
            this.vedge = 2*int.elem1.radius;
        end
        
        %------------------------------------------------------------------
        function addContactForceNormalToParticles(~,int)
            int.elem1.force = int.elem1.force + int.cforcen.total_force;
        end
        
        %------------------------------------------------------------------
        function addContactForceTangentToParticles(~,int)
            int.elem1.force = int.elem1.force + int.cforcet.total_force;
        end
        
        %------------------------------------------------------------------
        function addContactTorqueTangentToParticles(this,int)
            % Lever arm
            % Assumption: half of the overlap
            l = (int.elem1.radius-this.ovlp_n/2) * this.dir_n;
            
            % Torque from tangential contact force (3D due to cross-product)
            f = int.cforcet.total_force;
            torque = cross([l(1);l(2);0],[f(1);f(2);0]);
            
            % Add torque from tangential contact force to particle
            int.elem1.torque = int.elem1.torque + torque(3);
        end
        
        %------------------------------------------------------------------
        function addRollResistTorqueToParticles(~,int)
            int.elem1.torque = int.elem1.torque + int.rollres.torque;
        end
        
        %------------------------------------------------------------------
        function addDirectConductionToParticles(~,int)
            int.elem1.heat_rate = int.elem1.heat_rate + int.dconduc.total_hrate;
        end
        
        %------------------------------------------------------------------
        function addIndirectConductionToParticles(~,int)
            int.elem1.heat_rate = int.elem1.heat_rate + int.iconduc.total_hrate;
        end
    end
end