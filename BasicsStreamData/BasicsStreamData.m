%% Stream Data
% This example demonstrates how to stream data from QServer, parse the TCP
% packets received and account for the different Channel and Data types.

%% Prerequisites
% This script assumes familiarity with basics covered in the BasicsItemList example.
% Refer to that example for fundamental concepts if necessary. This script is geared
% towards users with an understanding of QServer's REST API.
clearvars;
ip = "192.168.100.47"; % Update to match the IP Address of your QServer.
url = "http://" + ip + ":8080/";
timeout = 120;  % Timeout duration for QServer responses.

% Reset the QServer to default configuration to ensure a known starting point.
putOptions = weboptions('MediaType','application/x-www-form-urlencoded', 'Timeout', timeout, 'RequestMethod','put');
getOptions = weboptions('MediaType','application/json', 'Timeout', timeout, 'RequestMethod','get');
webwrite(url + "system/settings/resetToDefaults", putOptions);

%% Enable Channels for Streaming
% This section checks if streaming is enabled on any channel and enables one if not.
% A channel with enabled streaming is required for receiving data over the TCP connection.
foundStreamingChannel = false;  % Initialize flag to detect a streaming channel.
itemList = webread(url + "item/list", getOptions);  % Retrieve the list of all items.
for index = 1:length(itemList)  % Loop through the items to find a streaming-enabled channel.
    itemInfo = itemList(index);

    % Target channel settings if the item is identified as a channel (ItemTypeIdentifier == 4).
    if itemInfo.ItemTypeIdentifier == 4
        itemId = itemInfo.ItemId;
        channelSettings = webread(url + "item/settings/?itemId=" + itemId, getOptions);

        % Check if settings exist and if the channel operation mode is enabled.
        if ~isempty(channelSettings.Settings) && channelSettings.OperationMode.Id ~= 0
            % Iterate through settings looking expressly for the "Streaming State".
            for dataIndex = 1:length(channelSettings.Settings)
                if strcmp(channelSettings.Data(dataIndex).Name, "Streaming State") && channelSettings.Data(dataIndex).Value == 1
                    foundStreamingChannel = true;
                    break;
                end
            end
        end
    end
    
    % If a channel with streaming is found, exit the loop early.
    if foundStreamingChannel
        break;
    end
end

% If no enabled streaming channel was found, throw an error.
if ~foundStreamingChannel
    error("At least one analog channel needs to be enabled for streaming to proceed with this example.")
end

%% Open TCP socket
% Retrieve the port for the TCP socket connection to the QServer from the setup endpoint.
response = webread(url + "datastream/setup", getOptions);
tcpPort = response.TCPPort;
tcpClient = tcpclient(ip, tcpPort, 'ConnectTimeout', 60);  % Set up TCP client with server IP and designated port.

%% Stream Data and Parse Packet
% Data streaming from QServer begins as soon as the TCP socket connection is established.
% To prevent buffer overflow, ensure swift data handling subsequent to this section. This example
% demonstrates parsing a single packet. For continuous streaming, implement a loop with appropriate
% multi-threading or asynchronous handling based on application needs.

% Define packet header structure to read required 32 bytes.
packetHeaderSize = 32;
packetHeader = read(tcpClient, packetHeaderSize, 'uint8');

% Parse individual elements of the packet header.
sequenceNumber = typecast(packetHeader(1:8), 'uint64');
transitTimestamp = typecast(packetHeader(9:16), 'double');
bufferLevel = typecast(packetHeader(17:20), 'single');
payloadSize = typecast(packetHeader(21:24), 'uint32');
byteOrderMarker = typecast(packetHeader(25:28), 'uint32');
payloadType = typecast(packetHeader(29:32), 'uint32');

% Read payload as specified by the payload size received in the packet header.
payload = read(tcpClient, double(payloadSize), 'uint8');  % Ensure payloadSize is cast to double for use with 'read'.

% For this example the socket will be closed here. This gives you the
% chance to step through the code and inspect how the data is parsed.
% Usually you'll only close the socket after you have collected all the
% data you need for your measurement.
clear tcpClient;

% Proceed with parsing only if the known supported payload type is received.
if payloadType == 0
    % Payload type of 0 indicates a standard data format including headers and data blocks.
    % Initialize parsing index and channel index.
    index = uint32(1);
    channelIndex = 1;

    % Loop to parse each channel's packet in the payload.
    while index < payloadSize
        % Parse the Generic Channel Header and Specific Channel Header for each channel data block.
        genericChannelHeaderLength = 24;
        genericChannelHeader = typecast(payload(index:(index + genericChannelHeaderLength - 1)), 'uint8');
        index = index + genericChannelHeaderLength;
        
        % Parse fields from the generic channel header.
        data(channelIndex).ChannelId = typecast(genericChannelHeader(1:4), 'int32');
        data(channelIndex).SampleType = typecast(genericChannelHeader(5:8), 'int32');
        data(channelIndex).ChannelType = typecast(genericChannelHeader(9:12), 'uint32');
        data(channelIndex).ChannelDataSize = typecast(genericChannelHeader(13:16), 'uint32');
        data(channelIndex).ChannelTimestamp = typecast(genericChannelHeader(17:24), 'uint64');
        
        % Parse specific headers and data blocks based on the channel type.
        switch data(channelIndex).ChannelType
            case 0 % For Analog Channels
                analogChannelHeader = payload(index:index + 19);
                index = index + 20;
                
                data(channelIndex).ChannelIntegrity = typecast(analogChannelHeader(1:4), 'int32');
                data(channelIndex).LevelCrossingOccurred = typecast(analogChannelHeader(5:8), 'int32');
                data(channelIndex).Level = typecast(analogChannelHeader(9:12), 'single');
                data(channelIndex).Min = typecast(analogChannelHeader(13:16), 'single');
                data(channelIndex).Max = typecast(analogChannelHeader(17:20), 'single');

                % When the Sample Type is set to 0, then no scaling is
                % needed.
                if (data(channelIndex).SampleType == 0)
                    data(channelIndex).DataBlock = typecast(payload(index:index + data(channelIndex).ChannelDataSize - 1), 'single');
                else
                    % This would trigger if the Controller's Analog Data
                    % Format setting is set to 'Raw'
                    scalingFactor = typecast(payload(index:index + 3), 'single');
                    index = index + 4;
                        
                    switch (data(channelIndex).SampleType)
                        case 1
                            % This is a standard 16 bit signed integer which can be converted to a single and scalled
                            valuesAsInt = typecast(payload(index:index + data(channelIndex).ChannelDataSize - 1), 'int16');
                            data(channelIndex).DataBlock = typecast(valuesAsInt, 'single').*scalingFactor;
                            
                        case 2
                            % Transferred as a 24 bit signed integer, which is not supported in MATLAB, hence you must create the 32 bit value and scale it.
                            for sampleIndex = 1:(data(channelIndex).ChannelDataSize / 3)
                                dataIndex = index + ((sampleIndex - 1) * 3);
                                valueAsBytes = payload(dataIndex:dataIndex + 2);
                                valueAsInt = bitshift(int32(valueAsBytes(3)), 24) ...  % Shift the first byte left by 24 bits (most significant byte)
                                                + bitshift(int32(valueAsBytes(2)), 16) ... % Shift the second byte left by 16 bits
                                                + bitshift(int32(valueAsBytes(1)), 8);     % Add the third byte by 8 bits
                                            
                                data(channelIndex).DataBlock(sampleIndex) = single(valueAsInt) * scalingFactor;
                            end
                            
                        case 3
                            % A standard 32 bit singed integer.
                            valuesAsInt = typecast(payload(index:index + data(channelIndex).ChannelDataSize - 1), 'int32'); 
                            data(channelIndex).DataBlock = typecast(valuesAsInt, 'single').*scalingFactor;
                            
                        otherwise
                            error("An invalid SampleType was sent and cannot be parsed.")
                    end
                end

                index = index + data(channelIndex).ChannelDataSize;
                
            case 1 % For Tacho Channels
                % Tacho channels does not have a Specific channel Header.
                % Hence read the specified amount of bytes into the data block.
                data(channelIndex).DataBlock = typecast(payload(index:index + data(channelIndex).ChannelDataSize - 1), 'double');
                index = index + data(channelIndex).ChannelDataSize;
        
            case 2 % For CAN Channels
                % The CAN Specific Channel Header is only a placeholder for
                % the time being, hence skip the 24 bytes.
                index = index + 24;
                
                % Capture the CAN Messages
                messageIndex = 1;
                endIndex = index + data(channelIndex).ChannelDataSize;
                while (index < endIndex)
                    data(channelIndex).DataBlock(messageIndex).Timestamp = typecast(payload(index:index+7), 'double');
                    data(channelIndex).DataBlock(messageIndex).Id = typecast(payload(index+8:index+11), 'uint32');
                    data(channelIndex).DataBlock(messageIndex).Header = payload(index+12);
                    data(channelIndex).DataBlock(messageIndex).FrameFormat = payload(index+13);
                    data(channelIndex).DataBlock(messageIndex).FrameType = payload(index+14);
                    data(channelIndex).DataBlock(messageIndex).DataFieldLength = uint32(payload(index+15));
                    data(channelIndex).DataBlock(messageIndex).Data = payload(index+16:index+16+data(channelIndex).DataBlock(messageIndex).DataFieldLength-1);
                     
                    index = index + 16 + data(channelIndex).DataBlock(messageIndex).DataFieldLength;
                end
        end
        
        % Remember to increase the index variables.
        channelIndex = channelIndex + 1;
    end
end

% Reminder to close the TCP socket if not already closed, and refer to detailed documentation.

% For detailed explanations of settings and configurations, consult the QServer user manual.
% This concludes the basic streaming example. For more resources and 
% documentation, visit the repository at www.github.com/Mecalc.