using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Media;

namespace TGOptiv10
{
    public partial class MouseKeyboardWindow : Window
    {
        private bool isDarkMode;

        public MouseKeyboardWindow(bool darkMode)
        {
            InitializeComponent();
            isDarkMode = darkMode;
            ApplyTheme();
            tbStatus.Text = "Please select an option...";
        }

        private void ApplyTheme()
        {
            if (isDarkMode)
            {
                ApplyDarkTheme();
            }
            else
            {
                ApplyLightTheme();
            }
        }

        private void ApplyDarkTheme()
        {
            // Update window background
            this.Background = (SolidColorBrush)Resources["DarkBackground"];
            MainGrid.Background = (SolidColorBrush)Resources["DarkBackground"];

            // Update text colors
            tbTitle.Foreground = (SolidColorBrush)Resources["DarkForeground"];
            tbbTitle.Foreground = (SolidColorBrush)Resources["DarkForeground"];
            tbbbTitle.Foreground = (SolidColorBrush)Resources["DarkForeground"];
            tbbbbTitle.Foreground = (SolidColorBrush)Resources["DarkForeground"];
            tbbbbbTitle.Foreground = (SolidColorBrush)Resources["DarkForeground"];
            tbStatus.Foreground = (SolidColorBrush)Resources["DarkForeground"];

            // Update button styles
            btnL.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnL.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnL.BorderBrush = Brushes.Gray;

            btnM.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnM.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnM.BorderBrush = Brushes.Gray;

            btnH.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnH.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnH.BorderBrush = Brushes.Gray;

            btnR.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnR.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnR.BorderBrush = Brushes.Gray;
        }

        private void ApplyLightTheme()
        {
            // Revert to default light theme
            this.Background = (SolidColorBrush)Resources["LightBackground"];
            MainGrid.Background = (SolidColorBrush)Resources["LightBackground"];

            // Update text colors
            tbTitle.Foreground = (SolidColorBrush)Resources["LightForeground"];
            tbbTitle.Foreground = (SolidColorBrush)Resources["LightForeground"];
            tbbbTitle.Foreground = (SolidColorBrush)Resources["LightForeground"];
            tbbbbTitle.Foreground = (SolidColorBrush)Resources["LightForeground"];
            tbbbbbTitle.Foreground = (SolidColorBrush)Resources["LightForeground"];
            tbStatus.Foreground = (SolidColorBrush)Resources["LightForeground"];

            // Update button styles
            btnL.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnL.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnL.BorderBrush = Brushes.Gray;

            btnM.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnM.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnM.BorderBrush = Brushes.Gray;

            btnH.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnH.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnH.BorderBrush = Brushes.Gray;

            btnR.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnR.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnR.BorderBrush = Brushes.Gray;
        }

        private void RunOptimization(string mode)
        {
            try
            {
                tbStatus.Text = $"Running {mode} selection optimization...";
                RefreshInterface();

                // Execution by mode
                switch (mode)
                {
                    case "L":
                        ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"" /v ""MouseDataQueueSize"" /t REG_DWORD /d ""34"" /f");
                        ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"" /v ""KeyboardDataQueueSize"" /t REG_DWORD /d ""34"" /f");
                        ExecutePowerShellCommandsForPCI("optimize");
                        ExecuteAdditionalRegistryCommands();
                        break;

                    case "M":
                        ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"" /v ""MouseDataQueueSize"" /t REG_DWORD /d ""24"" /f");
                        ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"" /v ""KeyboardDataQueueSize"" /t REG_DWORD /d ""24"" /f");
                        ExecutePowerShellCommandsForPCI("optimize");
                        ExecuteAdditionalRegistryCommands();
                        break;

                    case "H":
                        ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"" /v ""MouseDataQueueSize"" /t REG_DWORD /d ""19"" /f");
                        ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"" /v ""KeyboardDataQueueSize"" /t REG_DWORD /d ""19"" /f");
                        ExecutePowerShellCommandsForPCI("optimize");
                        ExecuteAdditionalRegistryCommands();
                        break;

                    case "R":
                        ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"" /v ""MouseDataQueueSize"" /t REG_DWORD /d ""256"" /f");
                        ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"" /v ""KeyboardDataQueueSize"" /t REG_DWORD /d ""256"" /f");
                        ExecutePowerShellCommandsForPCI("restore");
                        ExecuteDefaultRegistryCommands();
                        break;
                }

                tbStatus.Text = $"Optimization completed for {mode} selection!";
                MessageBox.Show($"{mode} selection optimization completed successfully!");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error during optimization: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                tbStatus.Text = "Optimization failed!";
            }
        }

        private void RefreshInterface()
        {
            Dispatcher.Invoke(() =>
            {
                tbStatus.UpdateLayout();
            });
        }

        private void ExecuteCommand(string command)
        {
            using (Process process = new Process())
            {
                ProcessStartInfo startInfo = new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = $"/C {command}",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    Verb = "runas" // Run as administrator
                };

                process.StartInfo = startInfo;
                process.Start();

                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();

                process.WaitForExit();

                // Log results for debugging
                Debug.WriteLine($"Command: {command}");
                Debug.WriteLine($"Output: {output}");
                if (!string.IsNullOrEmpty(error))
                    Debug.WriteLine($"Error: {error}");
            }
        }

        private void ExecutePowerShellCommandsForPCI(string mode)
        {
            string powerShellCommand = mode == "optimize" ? @"
                Get-PnpDevice -PresentOnly | 
                Where-Object { $_.InstanceId -like 'PCI\VEN_*' } | 
                ForEach-Object { 
                    $instanceId = $_.InstanceId.Replace('\', '\\');
                    $regPath = 'HKLM\SYSTEM\CurrentControlSet\Enum\' + $instanceId + '\Device Parameters';
                    
                    # Check if registry path exists before modifying
                    if (Test-Path (""HKLM:"" + $regPath.Replace('HKLM\', '\'))) {
                        reg add $regPath /v 'AllowIdleIrpInD3' /t REG_DWORD /d '0' /f 2>`$null;
                        reg add $regPath /v 'D3ColdSupported' /t REG_DWORD /d '0' /f 2>`$null;
                        reg add $regPath /v 'DeviceSelectiveSuspended' /t REG_DWORD /d '0' /f 2>`$null;
                        reg add $regPath /v 'EnableSelectiveSuspend' /t REG_DWORD /d '0' /f 2>`$null;
                        reg add $regPath /v 'EnhancedPowerManagementEnabled' /t REG_DWORD /d '0' /f 2>`$null;
                        reg add $regPath /v 'SelectiveSuspendEnabled' /t REG_DWORD /d '0' /f 2>`$null;
                        reg add $regPath /v 'SelectiveSuspendOn' /t REG_DWORD /d '0' /f 2>`$null;
                    }
                }
                Write-Host 'PCI device optimization completed.'"
                :
                @"
                Get-PnpDevice -PresentOnly | 
                Where-Object { $_.InstanceId -like 'PCI\VEN_*' } | 
                ForEach-Object { 
                    $instanceId = $_.InstanceId.Replace('\', '\\');
                    $regPath = 'HKLM\SYSTEM\CurrentControlSet\Enum\' + $instanceId + '\Device Parameters';
                    
                    # Check if registry path exists before deleting
                    if (Test-Path (""HKLM:"" + $regPath.Replace('HKLM\', '\'))) {
                        reg delete $regPath /v 'AllowIdleIrpInD3' /f 2>`$null;
                        reg delete $regPath /v 'D3ColdSupported' /f 2>`$null;
                        reg delete $regPath /v 'DeviceSelectiveSuspended' /f 2>`$null;
                        reg delete $regPath /v 'EnableSelectiveSuspend' /f 2>`$null;
                        reg delete $regPath /v 'EnhancedPowerManagementEnabled' /f 2>`$null;
                        reg delete $regPath /v 'SelectiveSuspendEnabled' /f 2>`$null;
                        reg delete $regPath /v 'SelectiveSuspendOn' /f 2>`$null;
                    }
                }
                Write-Host 'PCI device settings restored.'";

            ExecuteCommand($"powershell -Command \"{powerShellCommand}\"");
        }

        private void ExecuteAdditionalRegistryCommands()
        {
            // Thread Priority settings
            ExecuteCommand(@"reg add ""HKLM\SYSTEM\CurrentControlSet\Services\usbxhci\Parameters"" /v ""ThreadPriority"" /t REG_DWORD /d ""31"" /f");
            ExecuteCommand(@"reg add ""HKLM\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters"" /v ""ThreadPriority"" /t REG_DWORD /d ""31"" /f");
            ExecuteCommand(@"reg add ""HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters"" /v ""ThreadPriority"" /t REG_DWORD /d ""31"" /f");
            ExecuteCommand(@"reg add ""HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters"" /v ""ThreadPriority"" /t REG_DWORD /d ""31"" /f");

            // USB Settings
            ExecuteCommand(@"reg add ""HKLM\SYSTEM\CurrentControlSet\Services\USB"" /v ""DisableSelectiveSuspend"" /t REG_DWORD /d ""1"" /f");

            // CSRSS Priority
            ExecuteCommand(@"reg add ""HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"" /v ""CpuPriorityClass"" /t REG_DWORD /d ""4"" /f");
            ExecuteCommand(@"reg add ""HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"" /v ""IoPriority"" /t REG_DWORD /d ""3"" /f");

            // Accessibility Settings
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Accessibility\Keyboard Response"" /v ""Flags"" /t REG_SZ /d ""122"" /f");
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Accessibility\ToggleKeys"" /v ""Flags"" /t REG_SZ /d ""58"" /f");
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Accessibility\StickyKeys"" /v ""Flags"" /t REG_SZ /d ""506"" /f");
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Accessibility\MouseKeys"" /v ""Flags"" /t REG_SZ /d ""0"" /f");

            // Mouse Settings
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Mouse"" /v ""MouseSpeed"" /t REG_SZ /d ""0"" /f");
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Mouse"" /v ""MouseThreshold1"" /t REG_SZ /d ""0"" /f");
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Mouse"" /v ""MouseThreshold2"" /t REG_SZ /d ""0"" /f");
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Mouse"" /v ""MouseSensitivity"" /t REG_SZ /d ""10"" /f");

            // Keyboard Settings
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Keyboard"" /v ""KeyboardDelay"" /t REG_SZ /d ""0"" /f");
            ExecuteCommand(@"reg add ""HKCU\Control Panel\Keyboard"" /v ""KeyboardSpeed"" /t REG_SZ /d ""31"" /f");
        }

        private void ExecuteDefaultRegistryCommands()
        {
            // Default CSRSS Priority
            ExecuteCommand(@"reg add ""HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"" /v ""CpuPriorityClass"" /t REG_DWORD /d ""3"" /f");
            ExecuteCommand(@"reg add ""HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"" /v ""IoPriority"" /t REG_DWORD /d ""2"" /f");

            // Delete registry settings for USB devices
            string powerShellCommand = @"
        Get-PnpDevice -Class USB | 
        Where-Object { $_.InstanceId -like 'PCI\\VEN_*' } | 
        ForEach-Object { 
            $instanceId = $_.InstanceId.Replace('\', '\\');
            $regPath = 'HKLM\\SYSTEM\\CurrentControlSet\\Enum\\' + $instanceId + '\\Device Parameters';
            
            reg delete $regPath /v 'AllowIdleIrpInD3' /f;
            reg delete $regPath /v 'D3ColdSupported' /f;
            reg delete $regPath /v 'DeviceSelectiveSuspended' /f;
            reg delete $regPath /v 'EnableSelectiveSuspend' /f;
            reg delete $regPath /v 'EnhancedPowerManagementEnabled' /f;
            reg delete $regPath /v 'SelectiveSuspendEnabled' /f;
            reg delete $regPath /v 'SelectiveSuspendOn' /f;
        }
    ";

            ExecuteCommand($"powershell -NoProfile -Command \"{powerShellCommand}\"");

            // Delete Thread Priority settings
            ExecuteCommand(@"reg delete ""HKLM\SYSTEM\CurrentControlSet\Services\usbxhci\Parameters"" /v ""ThreadPriority"" /f");
            ExecuteCommand(@"reg delete ""HKLM\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters"" /v ""ThreadPriority"" /f");
            ExecuteCommand(@"reg delete ""HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters"" /v ""ThreadPriority"" /f");
            ExecuteCommand(@"reg delete ""HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters"" /v ""ThreadPriority"" /f");

            // Reset USB Selective Suspend
            ExecuteCommand(@"reg add ""HKLM\SYSTEM\CurrentControlSet\Services\USB"" /v ""DisableSelectiveSuspend"" /t REG_DWORD /d ""0"" /f");

            // Delete Accessibility Settings
            ExecuteCommand(@"reg delete ""HKCU\Control Panel\Accessibility\Keyboard Response"" /v ""Flags"" /f");
            ExecuteCommand(@"reg delete ""HKCU\Control Panel\Accessibility\ToggleKeys"" /v ""Flags"" /f");
            ExecuteCommand(@"reg delete ""HKCU\Control Panel\Accessibility\StickyKeys"" /v ""Flags"" /f");
            ExecuteCommand(@"reg delete ""HKCU\Control Panel\Accessibility\MouseKeys"" /v ""Flags"" /f");
        }

        private void BtnL_Click(object sender, RoutedEventArgs e) => RunOptimization("L");
        private void BtnM_Click(object sender, RoutedEventArgs e) => RunOptimization("M");
        private void BtnH_Click(object sender, RoutedEventArgs e) => RunOptimization("H");
        private void BtnR_Click(object sender, RoutedEventArgs e) => RunOptimization("R");
    }
}