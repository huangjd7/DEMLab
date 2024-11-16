%% BinKinematics_CylinderWlin class
%
%% Description
%
% This is a sub-class of the <BinKinematics.html BinKinematics> class for
% the implementation of the *Cylinder-Wall Line* binary kinematics for
% particle-wall interactions of types
% <Particle_Cylinder.html Particle Cylinder> and
% <Wall_Line.html Wall Line>.
%
classdef BinKinematics_CylinderWlin < BinKinematics
    %% Constructor method
    methods
        function this = BinKinematics_CylinderWlin()
            this = this@BinKinematics(BinKinematics.PARTICLE_WALL,BinKinematics.CYLINDER_WALL_LINE);
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
            % Needed properties
            P = p.coord;
            A = w.coord_ini;
            B = w.coord_end;
            M = B - A;
            
            % Running parameter at the orthogonal intersection
            t = dot(M,P-A)/w.len^2;
            
            % Normal direction from particle to wall
            if (t <= 0)
                this.dir = A-P;
            elseif (t >= 1)
                this.dir = B-P;
            else
                this.dir = (A + t * M) - P;
            end
            
            % Distance between particle surface and line segment
            this.dist  = norm(this.dir);
            this.distc = this.dist;
            this.separ = this.dist - p.radius;
        end
        
        %------------------------------------------------------------------
        function this = setOverlaps(this,int,dt)
            p = int.elem1; w = int.elem2;
            
            % Normal overlap and unit vector
            % Assumption: the ends of the wall are treated as a flat surface
            this.ovlp_n = -this.separ;
            this.dir_n  =  this.dir / norm(this.dir);
            
            % Positions of contact point
            % Assumption: discount the full overlap from particle
            cp = (p.radius - this.ovlp_n) * this.dir_n;
            cw = (p.coord+cp) - (w.coord_ini+w.coord_end)/2;
            
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
            r = int.elem1.radius;
            d = this.dist;
            
            % Contact radius
            this.contact_radius = sqrt(r^2-d^2);
            
            % Contact correction
            if (~isempty(int.corarea))
                % Adjusted radius
                int.corarea.fixRadius(int);
                
                % Adjusted distance consistent with adjusted radius
                this.distc = sqrt(r^2-this.contact_radius^2);
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