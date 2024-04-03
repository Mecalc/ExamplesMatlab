%% Read Item list
% This example will show how to read item list from QServer and read the
% data it provides.
 
%% Prerequisites
% Here the constant variables are defined which will not change throughout
% the example. You can change the IP address to match that of your Mecalc
% system.
ip = "192.168.100.32";
 
% Build a URL which will be used for the HTTP connection. The port is
% always 8080 for the Rest API.
url = "http://" + ip + ":8080/";
 
% Some commands can take some time to finish since QServer will configure
% the hardware according to the settings set. Do not make this value too
% small.
timeout = 120;
 
%% HTTP request
% Since all Rest API calls are made over HTTP socket, we need to do a web
% query here.
options = weboptions('MediaType','application/json', 'Timeout', timeout, 'RequestMethod','get');
 
% Use the "item/list" endpoint to read the item list from the system.
response = webread(url + "item/list", options);
 
% The response from QServer will be in a JSON format. When parsed in
% MATLAB you'll receive a nested struct where each line indexes an item.
% To view the struct with information of the first item, you simply access
% the first index.
controller = response(1)
 
% The output you'll see
%controller = 
% 
%  struct with fields:
%
%                ItemId: 1
%              ItemName: 'MicroQ'
%    ItemNameIdentifier: 30100
%              ItemType: 'Controller'
%    ItemTypeIdentifier: 0
 
% Here are descriptions for the fields:
% ItemId: This is an unique identifier for each item in the system. It is
% also used when changing operation modes and settings of the item.
% ItemName: A name for the item.
% ItemNameIdentifier: A unique number identifier for the item name.
% ItemType: A group this item type belongs to.
% ItemTypeIdentifier: A unique number identifier for the group.
 
% The different groups of Items include:
% Controller, SignalConditioner, Module and Channels.

% Items are constructed in a Family Tree formation.
% There is only one Controller, and it is always in position 1.
% A Controller can have multiple SignalConditioners as children, which are
% used to expand the channel count of a system by providing additional slots
% for Modules. However, a Controller can host a Module too.
% A Channel will always belong to a Module as a child.
% The purpose a Module serves is grouping settings of Channels which has
% an effect on all Channels, like sampling rate.
% Here is an example of the Item Tree:
% Controller
% - Module
%   - Channel
%   - Channel
% - SignalConditioner
%   - Module
%     - Channel
%     - Channel
%     - Channel
%     - Channel
%   - Empty
%   - Empty
%   - Empty
 
% To view the tree structure and see all the settings of all items, one can
% use the GET "system/settings" endpoint.
 
% Refer to the user manual for a in depth understanding on how the settings
% work and what is available.
 
% This is the end of the first example, to view more please visit our
% repository at www.github.com/Mecalc.
