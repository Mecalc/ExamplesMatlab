%% Configure Items
% This example demonstrates how to read the item list from QServer, set operation modes,
% and configure settings.

%% Prerequisites
% This script assumes familiarity with the basics covered in the BasicsItemList example.
% Refer to that example for fundamental concepts if necessary.
ip = "192.168.100.32"; % Update the IP Address to match your system.
url = "http://" + ip + ":8080/";
timeout = 120;

% Initialize the QServer to a default configuration to ensure a consistent starting point.
putOptions = weboptions('MediaType','application/x-www-form-urlencoded', 'Timeout', timeout, 'RequestMethod','put');
getOptions = weboptions('MediaType','application/json', 'Timeout', timeout, 'RequestMethod','get');
response = webwrite(url + "system/settings/resetToDefaults", putOptions);

%% Item Id and Operation Mode
% Begin by identifying the ItemId, which uniquely identifies each item and is critical for API interactions.
itemList = webread(url + "item/list", getOptions);
controllerId = itemList(1).ItemId;

% Each item has an Operation Mode, such as Disabled or Enabled. 
% It's advisable to read the current Operation Mode before attempting any configuration changes.
% Use the ItemId to specify the item of interest in your request.
controllerOperationMode = webread(url + "item/operationMode/?itemId=" + controllerId, getOptions)

% controllerOperationMode = 
% 
%   struct with fields:
% 
%                 ItemId: 1
%               ItemName: 'MicroQ'
%     ItemNameIdentifier: 30100
%               ItemType: 'Controller'
%     ItemTypeIdentifier: 0
%                   Info: [1×1 struct]
%        SettingsApplied: 1
%               Settings: [1×1 struct]
% The structure of controllerOperationMode includes additional information:
% - SettingsApplied: A boolean indicating whether the settings have been applied to the hardware.
% - Info: Additional details such as the item's serial number
controllerOperationMode.Info
% ans = 
% 
%   struct with fields:
% 
%      Name: 'SerialNumber'
%     Value: '0720M4652'

% - Settings: A list of settings available for modification.
controllerOperationMode.Settings
% ans = 
% 
%   struct with fields:
% 
%                Name: 'Operation Mode'
%                Type: 'Enumeration'
%     SupportedValues: [2×1 struct]
%               Value: 1

% - SupportedValues: A settings struct will always have a list of supported values which lists the available options.
controllerOperationMode.Settings.SupportedValues

% ans = 
% 
%   2×1 struct array with fields:
% 
%     Id
%     Description
% Each entry will have an Id and Description field as minimum. Some
% additional information might become available for other setting types.
controllerOperationMode.Settings.SupportedValues(1)
controllerOperationMode.Settings.SupportedValues(2)

% ans = 
% 
%   struct with fields:
% 
%              Id: 0
%     Description: 'Disabled'
% 
%              Id: 1
%     Description: 'Enabled'


%% Changing the Settings
% With the valid OperationMode verified, you can now retrieve and amend the settings.
controllerSettings = webread(url + "item/settings/?itemId=" + controllerId, getOptions)

% controllerSettings = 
% 
%   struct with fields:
% 
%                 ItemId: 1
%               ItemName: 'MicroQ'
%     ItemNameIdentifier: 30100
%               ItemType: 'Controller'
%     ItemTypeIdentifier: 0
%                   Info: [1×1 struct]
%          OperationMode: [1×1 struct]
%        SettingsApplied: 1
%               Settings: [2×1 struct]
% The structure of controllerSettings includes the selected operation mode too:
controllerSettings.OperationMode

% ans = 
% 
%   struct with fields:
% 
%     Description: 'Enabled'
%              Id: 1

% There are typically multiple settings, each with a list of SupportedValues indicating valid choices.
% To update the settings, change the desired Value field to one of the options provided in SupportedValues.
controllerSettings.Settings(1).Value = controllerSettings.Settings(1).SupportedValues(7).Id % Set Master Sampling rate to 204800
controllerSettings.Settings(2).Value = controllerSettings.Settings(2).SupportedValues(2).Id % Set Analog Sample Format to Raw

%% Update QServer
% Apply the updated settings by using a PUT request which requires converting MATLAB structs to JSON.
% Create headers and HTTP options for the request.
import matlab.net.http.*

acceptField = matlab.net.http.field.AcceptField([matlab.net.http.MediaType('text/*'), matlab.net.http.MediaType('application/json')]);
contentTypeField = matlab.net.http.field.ContentTypeField('application/json');
header = [acceptField contentTypeField];
putOptions = matlab.net.http.HTTPOptions('ConnectTimeout', timeout);
requestMessage = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.PUT, header, controllerSettings);

% Send the updated settings to the QServer using the constructed HTTP request.
response = requestMessage.send(url + "item/settings/?itemId=" + controllerId, putOptions);

% Always check for error messages after attempting a settings change. The QServer will reject invalid configurations.
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

%% Apply Settings to Hardware
% Finalize configuration by syncing cached settings to the hardware. The 'Apply' action is required
% after setting all desired configuration parameters for all items, rather than after each individual setting change.
requestMessage = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.PUT);
response = requestMessage.send(url + "system/settings/apply", putOptions);
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

% With the 'Apply' action completed, the new settings are synchronized with the hardware.

% For detailed explanations of settings and configurations, consult the QServer user manual.
% End of example. For more information and additional examples, visit the Mecalc repository at www.github.com/Mecalc.