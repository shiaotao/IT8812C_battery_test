%% IT8812C 电子负载控制程序
clear all; close all; clc;

%% 1. 建立USB连接
% 查找USB设备
visaInfo = visadevlist;
disp('可用的VISA设备：');
disp(visaInfo);

usbAddress = 'USB0::0x1AB1::0x0E11::0::INSTR';

try
    % 创建VISA对象
    load_device = visadev(usbAddress);
    
    % 设置通信参数
    load_device.Timeout = 5; % 5秒超时
    
    % 测试连接
    writeline(load_device, '*IDN?');
    device_info = readline(load_device);
    fprintf('连接成功！设备信息：%s\n', device_info);
    
catch ME
    error('无法连接到设备，请检查USB连接和地址设置');
end

%% 2. 配置电子负载
try
    % 复位设备
    writeline(load_device, '*RST');
    pause(1);
    
    % 设置为CC模式（恒流模式）
    writeline(load_device, 'FUNC CURR');
    pause(0.1);
    
    % 设置电流值（请根据实际需要修改，单位：A）
    current_setpoint = 1.0; % 1A，请根据实际需要修改
    writeline(load_device, sprintf('CURR %f', current_setpoint));
    pause(0.1);
    
    % 设置电流量程（可选，根据需要设置）
    % writeline(load_device, 'CURR:RANG 10'); % 设置10A量程
    
    % 打开输入
    writeline(load_device, 'INP ON');
    pause(0.5);
    
    fprintf('电子负载配置完成！\n');
    fprintf('模式：CC (恒流)\n');
    fprintf('设定电流：%.3f A\n', current_setpoint);
    
catch ME
    error('配置设备失败：%s', ME.message);
end

%% 3. 数据采集设置
sample_rate = 10; % Hz
duration = 60; % 秒
num_samples = sample_rate * duration;

% 预分配数据数组
time_data = zeros(num_samples, 1);
voltage_data = zeros(num_samples, 1);
current_data = zeros(num_samples, 1);
power_data = zeros(num_samples, 1);

% 创建实时绘图窗口
figure('Name', 'IT8812C 实时数据监控', 'Position', [100, 100, 1200, 800]);

% 电压子图
subplot(3, 1, 1);
h_voltage = plot(0, 0, 'b-', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('电压 (V)');
title('电压实时曲线');
grid on;
xlim([0 duration]);
ylim('auto');

% 电流子图
subplot(3, 1, 2);
h_current = plot(0, 0, 'r-', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('电流 (A)');
title('电流实时曲线');
grid on;
xlim([0 duration]);
ylim('auto');

% 功率子图
subplot(3, 1, 3);
h_power = plot(0, 0, 'g-', 'LineWidth', 1.5);
xlabel('时间 (s)');
ylabel('功率 (W)');
title('功率实时曲线');
grid on;
xlim([0 duration]);
ylim('auto');

%% 4. 开始数据采集
fprintf('\n开始数据采集...\n');
fprintf('采样率：%d Hz\n', sample_rate);
fprintf('持续时间：%d 秒\n', duration);
fprintf('总采样点数：%d\n', num_samples);
fprintf('\n按 Ctrl+C 可提前终止采集\n\n');

% 记录开始时间
start_time = tic;
sample_period = 1/sample_rate;

try
    for i = 1:num_samples
        % 记录时间戳
        current_time = toc(start_time);
        time_data(i) = current_time;
        
        % 读取电压
        writeline(load_device, 'MEAS:VOLT?');
        voltage_str = readline(load_device);
        voltage_data(i) = str2double(voltage_str);
        
        % 读取电流
        writeline(load_device, 'MEAS:CURR?');
        current_str = readline(load_device);
        current_data(i) = str2double(current_str);
        
        % 读取功率
        writeline(load_device, 'FETC:POW?');
        power_str = readline(load_device);
        power_data(i) = str2double(power_str);
        
        % 更新实时图形
        if mod(i, 5) == 0 % 每5个点更新一次图形，提高效率
            set(h_voltage, 'XData', time_data(1:i), 'YData', voltage_data(1:i));
            set(h_current, 'XData', time_data(1:i), 'YData', current_data(1:i));
            set(h_power, 'XData', time_data(1:i), 'YData', power_data(1:i));
            
            % 动态调整Y轴范围
            subplot(3, 1, 1);
            ylim('auto');
            subplot(3, 1, 2);
            ylim('auto');
            subplot(3, 1, 3);
            ylim('auto');
            
            drawnow;
        end
        
        % 显示进度
        if mod(i, sample_rate) == 0
            fprintf('已采集 %d/%d 秒...\n', round(current_time), duration);
        end
        
        % 等待到下一个采样时刻
        while toc(start_time) < (i * sample_period)
            % 空循环等待
        end
    end
    
    fprintf('\n数据采集完成！\n');
    
catch ME
    fprintf('\n数据采集被中断！\n');
    % 截取已采集的数据
    actual_samples = i - 1;
    time_data = time_data(1:actual_samples);
    voltage_data = voltage_data(1:actual_samples);
    current_data = current_data(1:actual_samples);
    power_data = power_data(1:actual_samples);
end

%% 5. 关闭输入
writeline(load_device, 'INP OFF');
fprintf('已关闭电子负载输入\n');

%% 6. 数据导出为CSV
% 创建数据表
data_table = table(time_data, voltage_data, current_data, power_data, ...
    'VariableNames', {'Time_s', 'Voltage_V', 'Current_A', 'Power_W'});

% 生成文件名（包含时间戳）
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
filename = sprintf('IT8812C_Data_%s.csv', timestamp);

% 保存为CSV文件
writetable(data_table, filename);
fprintf('\n数据已保存至：%s\n', filename);

%% 7. 计算并显示统计信息
fprintf('\n=== 数据统计 ===\n');
fprintf('电压 - 平均值：%.3f V, 最大值：%.3f V, 最小值：%.3f V\n', ...
    mean(voltage_data), max(voltage_data), min(voltage_data));
fprintf('电流 - 平均值：%.3f A, 最大值：%.3f A, 最小值：%.3f A\n', ...
    mean(current_data), max(current_data), min(current_data));
fprintf('功率 - 平均值：%.3f W, 最大值：%.3f W, 最小值：%.3f W\n', ...
    mean(power_data), max(power_data), min(power_data));

%% 8. 清理资源
clear load_device;
fprintf('\n程序执行完毕！\n');