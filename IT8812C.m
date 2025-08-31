function IT8812C_DataLogger()
% IT8812C电子负载数据采集程序
% 功能：CC模式下以10Hz采样电压、电流、功率60秒，实时绘图并导出CSV

clc; clear; close all;

%% 配置参数
SAMPLE_RATE = 10;           % 采样频率 10Hz
SAMPLE_TIME = 60;           % 采样时间 60秒
SAMPLE_INTERVAL = 1/SAMPLE_RATE; % 采样间隔 0.1秒
TOTAL_SAMPLES = SAMPLE_RATE * SAMPLE_TIME; % 总采样点数 600

% 设置CC模式参数
CC_CURRENT = 1.0;           % 设定电流值 1A (请根据实际需求修改)

%% 查找并连接USB设备
try
    % 查找USB TMC设备
    devices = instrhwinfo('visa');
    usb_devices = {};
    
    if ~isempty(devices.ObjectConstructorName)
        for i = 1:length(devices.ObjectConstructorName)
            if contains(devices.ObjectConstructorName{i}, 'USB')
                usb_devices{end+1} = devices.ObjectConstructorName{i}{2};
            end
        end
    end
    
    if isempty(usb_devices)
        error('未找到USB设备，请检查IT8812C是否正确连接');
    end
    
    % 显示找到的设备
    fprintf('找到以下USB设备:\n');
    for i = 1:length(usb_devices)
        fprintf('%d: %s\n', i, usb_devices{i});
    end
    
    % 选择设备（如果有多个设备）
    if length(usb_devices) == 1
        selected_device = usb_devices{1};
    else
        device_idx = input('请选择设备编号: ');
        selected_device = usb_devices{device_idx};
    end
    
    % 创建VISA对象
    load_instrument = visa('ni', selected_device);
    
    % 配置通信参数
    load_instrument.Timeout = 5;
    load_instrument.InputBufferSize = 1024;
    load_instrument.OutputBufferSize = 1024;
    
    % 打开连接
    fopen(load_instrument);
    fprintf('成功连接到设备: %s\n', selected_device);
    
catch ME
    error('连接设备失败: %s', ME.message);
end

%% 初始化设备
try
    % 查询设备信息
    fprintf(load_instrument, '*IDN?');
    device_info = fscanf(load_instrument);
    fprintf('设备信息: %s\n', device_info);
    
    % 重置设备
    fprintf(load_instrument, '*RST');
    pause(1);
    
    % 设置CC模式
    fprintf(load_instrument, 'FUNC CURR');
    fprintf('设置为CC模式\n');
    
    % 设置电流值
    fprintf(load_instrument, sprintf('CURR %.3f', CC_CURRENT));
    fprintf('设置电流值: %.3fA\n', CC_CURRENT);
    
    % 查询当前设置确认
    fprintf(load_instrument, 'FUNC?');
    mode = strtrim(fscanf(load_instrument));
    fprintf('当前模式: %s\n', mode);
    
    fprintf(load_instrument, 'CURR?');
    current_setting = str2double(fscanf(load_instrument));
    fprintf('当前电流设置: %.3fA\n', current_setting);
    
catch ME
    fclose(load_instrument);
    delete(load_instrument);
    error('设备初始化失败: %s', ME.message);
end

%% 数据采集准备
% 预分配数据数组
time_data = zeros(TOTAL_SAMPLES, 1);
voltage_data = zeros(TOTAL_SAMPLES, 1);
current_data = zeros(TOTAL_SAMPLES, 1);
power_data = zeros(TOTAL_SAMPLES, 1);

% 创建实时绘图窗口
figure('Name', 'IT8812C 实时数据监控', 'Position', [100, 100, 1200, 800]);

% 子图1: 电压
subplot(3,1,1);
h_voltage = plot(0, 0, 'b-', 'LineWidth', 1.5);
grid on;
xlabel('时间 (s)');
ylabel('电压 (V)');
title('电压实时监控');
voltage_ax = gca;

% 子图2: 电流
subplot(3,1,2);
h_current = plot(0, 0, 'r-', 'LineWidth', 1.5);
grid on;
xlabel('时间 (s)');
ylabel('电流 (A)');
title('电流实时监控');
current_ax = gca;

% 子图3: 功率
subplot(3,1,3);
h_power = plot(0, 0, 'g-', 'LineWidth', 1.5);
grid on;
xlabel('时间 (s)');
ylabel('功率 (W)');
title('功率实时监控');
power_ax = gca;

%% 开始数据采集
fprintf('\n开始数据采集...\n');
fprintf('采样频率: %dHz, 采样时间: %ds\n', SAMPLE_RATE, SAMPLE_TIME);

% 提示用户是否开启负载输入
user_input = input('是否开启负载输入? (y/n): ', 's');
if strcmpi(user_input, 'y')
    fprintf(load_instrument, 'INP ON');
    fprintf('负载输入已开启\n');
    input_enabled = true;
else
    fprintf('负载输入保持关闭状态\n');
    input_enabled = false;
end

% 开始计时
start_time = tic;
last_sample_time = 0;

try
    for i = 1:TOTAL_SAMPLES
        % 等待到下一个采样点
        current_time = toc(start_time);
        expected_time = (i-1) * SAMPLE_INTERVAL;
        
        if current_time < expected_time
            pause(expected_time - current_time);
        end
        
        % 读取测量值
        fprintf(load_instrument, 'MEAS:VOLT?');
        voltage = str2double(fscanf(load_instrument));
        
        fprintf(load_instrument, 'MEAS:CURR?');
        current = str2double(fscanf(load_instrument));
        
        fprintf(load_instrument, 'FETC:POW?');
        power = str2double(fscanf(load_instrument));
        
        % 存储数据
        time_data(i) = toc(start_time);
        voltage_data(i) = voltage;
        current_data(i) = current;
        power_data(i) = power;
        
        % 更新实时绘图
        if mod(i, 5) == 0 % 每5个点更新一次图形以提高性能
            % 更新电压图
            set(h_voltage, 'XData', time_data(1:i), 'YData', voltage_data(1:i));
            set(voltage_ax, 'XLim', [max(0, time_data(i)-10), time_data(i)+1]);
            
            % 更新电流图
            set(h_current, 'XData', time_data(1:i), 'YData', current_data(1:i));
            set(current_ax, 'XLim', [max(0, time_data(i)-10), time_data(i)+1]);
            
            % 更新功率图
            set(h_power, 'XData', time_data(1:i), 'YData', power_data(1:i));
            set(power_ax, 'XLim', [max(0, time_data(i)-10), time_data(i)+1]);
            
            drawnow;
        end
        
        % 显示进度
        if mod(i, 50) == 0 % 每5秒显示一次进度
            progress = i / TOTAL_SAMPLES * 100;
            fprintf('采集进度: %.1f%% | V=%.3fV, I=%.3fA, P=%.3fW\n', ...
                    progress, voltage, current, power);
        end
    end
    
catch ME
    fprintf('数据采集中断: %s\n', ME.message);
end

%% 关闭设备输入
if input_enabled
    fprintf(load_instrument, 'INP OFF');
    fprintf('负载输入已关闭\n');
end

%% 数据处理和导出
fprintf('\n数据采集完成！\n');

% 计算统计数据
avg_voltage = mean(voltage_data);
avg_current = mean(current_data);
avg_power = mean(power_data);
max_voltage = max(voltage_data);
max_current = max(current_data);
max_power = max(power_data);
min_voltage = min(voltage_data);
min_current = min(current_data);
min_power = min(power_data);

fprintf('\n=== 数据统计 ===\n');
fprintf('电压: 平均=%.3fV, 最大=%.3fV, 最小=%.3fV\n', avg_voltage, max_voltage, min_voltage);
fprintf('电流: 平均=%.3fA, 最大=%.3fA, 最小=%.3fA\n', avg_current, max_current, min_current);
fprintf('功率: 平均=%.3fW, 最大=%.3fW, 最小=%.3fW\n', avg_power, max_power, min_power);

% 生成文件名（包含时间戳）
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
filename = sprintf('IT8812C_Data_%s.csv', timestamp);

% 创建数据表
data_table = table(time_data, voltage_data, current_data, power_data, ...
                   'VariableNames', {'Time_s', 'Voltage_V', 'Current_A', 'Power_W'});

% 导出CSV文件
try
    writetable(data_table, filename);
    fprintf('数据已导出到: %s\n', filename);
catch ME
    fprintf('导出文件失败: %s\n', ME.message);
    
    % 尝试保存到工作区
    save(sprintf('IT8812C_Data_%s.mat', timestamp), 'time_data', 'voltage_data', 'current_data', 'power_data');
    fprintf('数据已保存为MAT文件\n');
end

%% 最终绘图更新
% 更新完整数据图
set(h_voltage, 'XData', time_data, 'YData', voltage_data);
set(voltage_ax, 'XLim', [0, max(time_data)]);

set(h_current, 'XData', time_data, 'YData', current_data);
set(current_ax, 'XLim', [0, max(time_data)]);

set(h_power, 'XData', time_data, 'YData', power_data);
set(power_ax, 'XLim', [0, max(time_data)]);

% 保存图像
try
    saveas(gcf, sprintf('IT8812C_Plot_%s.png', timestamp));
    fprintf('图像已保存\n');
catch
    fprintf('保存图像失败\n');
end

%% 清理资源
try
    fclose(load_instrument);
    delete(load_instrument);
    fprintf('设备连接已关闭\n');
catch
    fprintf('关闭设备连接时出错\n');
end

fprintf('\n程序执行完成！\n');

end