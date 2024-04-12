%% Read Item List
% This script demonstrates how to retrieve a list of items from the QServer via its REST API
% and process the response data.

%% Prerequisites
% Define constant variables that remain unchanged for the duration of this script.
% Replace the IP address with the IP of your Mecalc system as necessary.
ip = "192.168.100.32";

% Construct the base URL for HTTP requests. Port 8080 is used by default for the REST API.
url = "http://" + ip + ":8080/";

% REST API calls may require time to execute, as QServer configures hardware based on provided settings.
% Ensure the timeout period is sufficiently long to accommodate for this.
timeout = 120;

%% HTTP Request
% REST API interactions are carried out through HTTP requests. In this instance,
% a GET request is used to obtain data from the API.
options = weboptions('MediaType','application/json', 'Timeout', timeout, 'RequestMethod','get');

% Access the 'item/list' API endpoint to fetch the list of items from the QServer.
response = webread(url + "item/list", options);

% The QServer responds with JSON-formatted data. MATLAB parses this JSON into a nested struct,
% with each item represented by an individual struct array element.
% For example, to display data from the first item in the list:
controller = response(1)

% Expected output:
%   controller =
% 
%   struct with fields:
%
%                ItemId: 1
%              ItemName: 'MicroQ'
%    ItemNameIdentifier: 30100
%              ItemType: 'Controller'
%    ItemTypeIdentifier: 0

% Field descriptions:
%   ItemId: Unique identifier for the item within the system, used for item configuration and operation.
%   ItemName: Descriptive name assigned to the item.
%   ItemNameIdentifier: Unique numeric code assigned to the item name.
%   ItemType: Category the item belongs to.
%   ItemTypeIdentifier: Unique numeric code assigned to the item type.

% The QServer maintains items in a family-tree-like hierarchy:
%   - Controller: The top-level item. There is only one Controller, typically at the first position.
%   - SignalConditioner: Devices that extend the system's capability by providing slots for more Modules.
%   - Module: Components that contain common settings affecting all of their child Channels, like sampling rate.
%   - Channel: The leaf nodes representing individual data channels contained within Modules.

% For example, the item hierarchy might appear as follows:
%   Controller
%   |-- Module
%       |-- Channel
%       |-- Channel
%   |-- SignalConditioner
%       |-- Module
%           |-- Channel
%           |-- Channel
%           |-- Channel
%           |-- Channel
%       |-- Empty slots
%       |-- Empty slots
%       |-- Module
%           |-- Channel
%           |-- Channel
%           |-- Channel
%           |-- Channel

% To view the entire system configuration, including the hierarchical structure and settings for all items,
% you can use the 'system/settings' endpoint with a GET request.

% Consult the QServer user manual for detailed information on configuration options and settings.

% This concludes the introductory example. For further examples and documentation, visit the Mecalc repository at www.github.com/Mecalc.