%% Configure Items
% This example will show how to read item list from QServer and configure
% item operation modes and settings.
 
%% Prerequisites
% This example builds on top of the BasicsItemList example. If you feel
% lost at any point please refer the BasicsItemList example for guidance.
ip = "192.168.100.32";
url = "http://" + ip + ":8080/";
timeout = 120;
 
getOptions = weboptions('MediaType','application/json', 'Timeout', timeout, 'RequestMethod','get');
response = webread(url + "item/list", getOptions);
 
%% Item Id and Operation Mode
% The first variable to take into consideration is the ItemId. This unique
% ID will be used for all PUT endpoints which will change settings.
% We'll start with the controller.
controllerId = response(1).ItemId;
 
% All Items have an Operation Mode, which includes Disabled and Enabled
% amongst others options. Its generally a good idea to read the Operation Mode
% first before trying to change the settings. When the Operation Mode is
% incorrect, then you'll have to change it first before reading the
% settings. It is important to send QServer the ItemId now that It knows
% which Item you are interacting with, hence the ?itemId= parameter.
controllerOperationMode = webread(url + "item/operationMode/?itemId=" + controllerId, getOptions)
 
%controllerOperationMode = 
%
%  struct with fields:
%
%                ItemId: 1
%              ItemName: 'MicroQ'
%    ItemNameIdentifier: 30100
%              ItemType: 'Controller'
%    ItemTypeIdentifier: 0
%                  Info: [1×1 struct]
%       SettingsApplied: 1
%              Settings: [1×1 struct]
 
% A few extra field has been added:
% Info: A struct with additional information of the item will be displayed
% E.g > controllerOperationMode.Info =
%     Name: 'SerialNumber'
%    Value: '0720M4652'
% SettingsApplied: A boolean to indicatio whether the settings has been
%                  applied to the hardware. More on this later.
% Settings: Settings which are available to view or change.
% E.g > controllerOperationMode.Settings =
%               Name: 'Operation Mode'
%               Type: 'Enumeration'
%    SupportedValues: [2×1 struct]
%              Value: 1
% SupportedValues is a list of options which are valid, containing both the
% value and description of the option.
 
% From the SupportedValue list you'll see that the controller is set to
% Enabled which is correct for this example.
 
%% Changing the settings
% Now that we have the ItemId and know the OperationMode is valid, we can
% query the settings and update it accordingly.
controllerSettings = webread(url + "item/settings/?itemId=" + controllerId, getOptions)
 
%controllerSettings = 
%
%  struct with fields:
%
%                ItemId: 1
%              ItemName: 'MicroQ'
%    ItemNameIdentifier: 30100
%              ItemType: 'Controller'
%    ItemTypeIdentifier: 0
%                  Info: [1×1 struct]
%         OperationMode: [1×1 struct]
%       SettingsApplied: 1
%              Settings: [2×1 struct]
 
% Much of the same information is sent then before, except now the
% OperationMode is also shown.
 
%>> controllerSettings.OperationMode
%
%ans = 
%
%  struct with fields:
%
%    Description: 'Enabled'
%             Id: 1
 
% There are two entries in the Settings list this time. Lets view both:
%>> controllerSettings.Settings(1)
%
%ans = 
%
%  struct with fields:
%
%               Name: 'Master Sampling Rate'
%               Type: 'Enumeration'
%    SupportedValues: [7×1 struct]
%              Value: 6
% The Master Sampling Rate controls the system sampling clock which is
% connected to every Module. Modules will use this clock to down sample to
% lower values if desired. There are 7 values to choose from:
%>> controllerSettings.Settings(1).SupportedValues.Description
%
%ans =
%
%    '131072 Hz'
%    '160000 Hz'
%    '163840 Hz'
%    '176400 Hz'
%    '192000 Hz'
%    '200000 Hz'
%    '204800 Hz'
 
%>> controllerSettings.Settings(2)
%
%ans = 
%
%  struct with fields:
%
%               Name: 'Analog Data Streaming Format'
%               Type: 'Enumeration'
%    SupportedValues: [2×1 struct]
%              Value: 0
% The 'Analog Data Streaming Format' controls how the data is formated when
% streaming from a TCP or Websocket. Two options exist:
%>> controllerSettings.Settings(2).SupportedValues.Description
%
%ans =
%
%    'Processed'
%    'Raw'
% 'Processed' means the system will format the Analog Data as Doubles,
% 'Raw' format it as Integers where the user must apply a scaling factor.
 
% Changing the Settings is easy, you simply update the Value field to the
% new value, and pass the settings struct back to QServer. Valid options
% are shown in the SupportedValues field as an ID.
controllerSettings.Settings(1).Value = 6; % MSR set to 204800
controllerSettings.Settings(2).Value = 1; % Raw data mode
 
%% Update QServer
% To update the settings on QServer, you need to use the PUT action to send
% the settings. A few extra steps are required to convert the MATLAB
% structs back to JSON.
import matlab.net.http.*
contentTypeField = matlab.net.http.field.ContentTypeField('application/json');
type1 = matlab.net.http.MediaType('text/*');
type2 = matlab.net.http.MediaType('application/json');
acceptField = matlab.net.http.field.AcceptField([type1 type2]);
 
header = [acceptField contentTypeField];
method = matlab.net.http.RequestMethod.PUT;
 
putOptions = matlab.net.http.HTTPOptions('ConnectTimeout', timeout);
request = matlab.net.http.RequestMessage(method, header, controllerSettings);
 
clear response
response = request.send(url + "item/settings/?itemId=" + controllerId, putOptions);
 
% It is important to check for error messages when changing settings.
% QServer will not accept invalid settings, hence if you change settings
% without inspecting the error message, you might end up with a different
% configuration than expected.
if (~isempty(response.Body.Data))
    if response.Body.Data.TypeCode == 1
        % Type = 1, Info message:
        warning(response.Body.Data.Message)
    end
    if response.Body.Data.TypeCode == 2
        % Type = 2, Error message:
        error(response.Body.Data.Message)
    end
end
 
% Once the endpoint has been called, QServer will validate the settings and
% if valid, store it in a cache. To sync the cache to the hardware you
% must:
 
%% Apply
% This is the last step when changing settings. When the SettingsApplied
% field is False (0) for any item/settings or item/operationMode then an
% Apply is needed to sync the settings.
% An Apply can be called after ALL settings on all Items have been set. No
% need to Apply after each PUT item/settings.
clear response
request = matlab.net.http.RequestMessage(method);
response = request.send(url + "system/settings/apply", putOptions);
if (~isempty(response.Body.Data))
    if response.Body.Data.TypeCode == 1
        % Type = 1, Info message:
        warning(response.Body.Data.Message)
    end
    if response.Body.Data.TypeCode == 2
        % Type = 2, Error message:
        error(response.Body.Data.Message)
    end
end
 
% After Apply your new settings are synchronised to the Hardware.
 
% Refer to the user manual for a in depth understanding on how the settings
% work and what is available.
 
% This is the end of the second example, to view more please visit our
% repository at www.github.com/Mecalc.
