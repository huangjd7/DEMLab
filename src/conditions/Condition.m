%% Condition class
%
%% Description
%
% This is a handle heterogeneous super-class for the definition of
% conditions.
%
% A condition is a time function that returns a value for each provided
% time value.
%
% This super-class defines abstract methods that must be implemented in
% the derived *sub-classes*:
%
% * <Condition_Constant.html Condition_Constant> (default)
% * <Condition_Linear.html Condition_Linear>
% * <Condition_Oscillatory.html Condition_Oscillatory>
% * <Condition_Table.html Condition_Table>
%
classdef Condition < handle & matlab.mixin.Heterogeneous
    %% Constant values
    properties (Constant = true, Access = public)
        % Types of condition variation
        CONSTANT    = uint8(1);
        LINEAR      = uint8(2);
        OSCILLATORY = uint8(3);
        TABLE       = uint8(4);
        
        % Types of table data interpolation methods
        INTERP_LINEAR = uint8(1);
        INTERP_MAKIMA = uint8(2);
        INTERP_PCHIP  = uint8(3);
        INTERP_SPLINE = uint8(4);
    end
    
    %% Public properties
    properties (SetAccess = public, GetAccess = public)
        type      uint8  = uint8.empty;    % flag for type of condition variation
        interval  double = double.empty;   % time interval of activation (initial,final)
        init_time double = double.empty;   % time of activation
    end
    
    %% Constructor method
    methods
        function this = Condition(type)
            if (nargin > 0)
                this.type = type;
            end
        end
    end
    
    %% Default sub-class definition
    methods (Static, Access = protected)
        function defaultObject = getDefaultScalarElement
            defaultObject = Condition_Constant;
        end
    end
    
    %% Abstract methods: implemented in derived sub-classes
    methods (Abstract)
        %------------------------------------------------------------------
        setDefaultProps(this);
        
        %------------------------------------------------------------------
        val = getValue(this,time);
    end
    
    %% Public methods
    methods
        %------------------------------------------------------------------
        function is = isActive(this,time)
            is = isempty(this.interval) || (time >= min(this.interval) && time <= max(this.interval));
        end
    end
end