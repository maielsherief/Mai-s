classdef SafetySystemApp < matlab.apps.AppBase

    % Properties corresponding to UI components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        GridLayout            matlab.ui.container.GridLayout
        COMPortDropDown       matlab.ui.control.DropDown
        COMPortLabel          matlab.ui.control.Label
        ConnectButton         matlab.ui.control.StateButton
        VoltageGauge          matlab.ui.control.Gauge
        VoltageLabel          matlab.ui.control.Label
        GasGauge              matlab.ui.control.LinearGauge
        GasLabel              matlab.ui.control.Label
        StatusLamp            matlab.ui.control.Lamp
        StatusLabel           matlab.ui.control.Label
        ManualSwitch          matlab.ui.control.Switch
        SwitchLabel           matlab.ui.control.Label
        UIAxes                matlab.ui.control.UIAxes
    end

    % Private properties for internal data handling
    properties (Access = private)
        SerialObj             % serialport object
        TimeData              % Buffer for time axis
        VoltData              % Buffer for voltage history
        GasData               % Buffer for gas history
        StartTime             % Reference timer
    end

    % Callbacks and helper methods
    methods (Access = private)

        % Real-time serial data read callback
        function readSerialData(app, ~, ~)
            try
                if app.SerialObj.NumBytesAvailable > 0
                    dataStr = readline(app.SerialObj);
                    tokens = str2double(split(strtrim(dataStr), ','));

                    if length(tokens) == 2 && ~any(isnan(tokens))
                        vVal = tokens(1);
                        gVal = tokens(2);

                        % Update Gauge Displays
                        app.VoltageGauge.Value = min(max(vVal, 0), 12);
                        app.GasGauge.Value = min(max(gVal, 0), 1000);

                        % Update Alarm Lamp Status
                        if vVal >= 8.0 || gVal >= 300
                            app.StatusLamp.Color = [1.0 0.0 0.0]; % Red (ALARM)
                        else
                            app.StatusLamp.Color = [0.0 1.0 0.0]; % Green (NORMAL)
                        end

                        % Store Time-Series Telemetry
                        t = toc(app.StartTime);
                        app.TimeData(end+1) = t;
                        app.VoltData(end+1) = vVal;
                        app.GasData(end+1)  = gVal;

                        % Sliding window (keep last 50 data points)
                        if length(app.TimeData) > 50
                            app.TimeData(1) = [];
                            app.VoltData(1) = [];
                            app.GasData(1)  = [];
                        end

                        % Refresh Live Chart
                        plot(app.UIAxes, app.TimeData, app.VoltData, '-b', 'LineWidth', 1.5);
                        hold(app.UIAxes, 'on');
                        yyaxis(app.UIAxes, 'right');
                        plot(app.UIAxes, app.TimeData, app.GasData, '-r', 'LineWidth', 1.5);
                        yyaxis(app.UIAxes, 'left');
                        hold(app.UIAxes, 'off');
                        
                        xlabel(app.UIAxes, 'Time (s)');
                        app.UIAxes.YAxis(1).Color = 'b';
                        app.UIAxes.YAxis(2).Color = 'r';
                        title(app.UIAxes, 'Real-Time Telemetry Stream');
                    end
                end
            catch
                % Catch transient buffer read errors without crashing
            end
        end

        % Connect / Disconnect Toggle Button
        function ConnectButtonValueChanged(app, ~)
            if app.ConnectButton.Value
                selectedPort = app.COMPortDropDown.Value;
                try
                    app.SerialObj = serialport(selectedPort, 9600);
                    configureTerminator(app.SerialObj, "LF");
                    configureCallback(app.SerialObj, "terminator", @(src, evt)app.readSerialData(src, evt));

                    app.ConnectButton.Text = 'Disconnect';
                    app.ConnectButton.BackgroundColor = [0.8 0.2 0.2];
                    app.StartTime = tic;
                    app.TimeData = []; app.VoltData = []; app.GasData = [];
                catch ME
                    app.ConnectButton.Value = false;
                    uialert(app.UIFigure, ME.message, 'Connection Failed');
                end
            else
                if ~isempty(app.SerialObj) && isvalid(app.SerialObj)
                    configureCallback(app.SerialObj, "off");
                    delete(app.SerialObj);
                end
                app.ConnectButton.Text = 'Connect';
                app.ConnectButton.BackgroundColor = [0.2 0.8 0.2];
            end
        end

        % Manual Override Toggle Switch
        function ManualSwitchValueChanged(app, ~)
            if ~isempty(app.SerialObj) && isvalid(app.SerialObj)
                if strcmp(app.ManualSwitch.Value, 'ON')
                    write(app.SerialObj, '1', 'char');
                else
                    write(app.SerialObj, '0', 'char');
                end
            end
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)
            % Main UI Window
            app.UIFigure = uifigure('Position', [100 100 850 500], 'Name', 'Dual-Sensor Alarm Monitor');

            % Grid Layout
            app.GridLayout = uigridlayout(app.UIFigure, [3, 3]);
            app.GridLayout.RowHeight = {50, 200, '1x'};
            app.GridLayout.ColumnWidth = {220, 220, '1x'};

            % COM Port Label & Dropdown
            app.COMPortLabel = uilabel(app.GridLayout, 'Text', 'COM Port:');
            app.COMPortLabel.Layout.Row = 1; app.COMPortLabel.Layout.Column = 1;

            availablePorts = serialportlist("available");
            if isempty(availablePorts), availablePorts = "COM2"; end
            app.COMPortDropDown = uidropdown(app.GridLayout, 'Items', availablePorts);
            app.COMPortDropDown.Layout.Row = 1; app.COMPortDropDown.Layout.Column = 1;

            % Connect Button
            app.ConnectButton = uibutton(app.GridLayout, 'state', 'Text', 'Connect');
            app.ConnectButton.Layout.Row = 1; app.ConnectButton.Layout.Column = 2;
            app.ConnectButton.BackgroundColor = [0.2 0.8 0.2];
            app.ConnectButton.ValueChangedFcn = createCallbackFcn(app, @ConnectButtonValueChanged, true);

            % Voltage Circular Gauge (0-12V range with 2V tick steps: 8V trigger clearly visible)
            app.VoltageGauge = uigauge(app.GridLayout, 'circular', 'Limits', [0 12]);
            app.VoltageGauge.Layout.Row = 2; app.VoltageGauge.Layout.Column = 1;
            app.VoltageGauge.MajorTicks = 0:2:12;

            % Gas Linear Gauge (Spaced ticks: 0, 200, 400, 600, 800, 1000 to prevent text overlap)
            app.GasGauge = uigauge(app.GridLayout, 'linear', 'Limits', [0 1000]);
            app.GasGauge.Layout.Row = 2; app.GasGauge.Layout.Column = 2;
            app.GasGauge.MajorTicks = 0:200:1000;

            % System Alarm Lamp
            app.StatusLamp = uilamp(app.GridLayout);
            app.StatusLamp.Layout.Row = 1; app.StatusLamp.Layout.Column = 3;
            app.StatusLamp.Color = [0 1 0];

            % Manual Override Switch
            app.ManualSwitch = uiswitch(app.GridLayout, 'slider', 'Items', {'OFF', 'ON'});
            app.ManualSwitch.Layout.Row = 2; app.ManualSwitch.Layout.Column = 3;
            app.ManualSwitch.ValueChangedFcn = createCallbackFcn(app, @ManualSwitchValueChanged, true);

            % Live Plot Axes
            app.UIAxes = uiaxes(app.GridLayout);
            app.UIAxes.Layout.Row = 3; app.UIAxes.Layout.Column = [1 3];
            ylabel(app.UIAxes, 'Voltage (V)');
            yyaxis(app.UIAxes, 'right');
            ylabel(app.UIAxes, 'Gas (ADC)');
            yyaxis(app.UIAxes, 'left');
        end
    end

    methods (Access = public)
        function app = SafetySystemApp
            createComponents(app);
            registerApp(app, app.UIFigure);
        end

        function delete(app)
            if ~isempty(app.SerialObj) && isvalid(app.SerialObj)
                delete(app.SerialObj);
            end
            delete(app.UIFigure);
        end
    end
end