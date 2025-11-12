using System;
using System.IO;
using System.Diagnostics;
using System.Text;
using System.Windows;
using System.Windows.Media;

namespace TGOptiv10
{
    public partial class DiskTypeWindow : Window
    {
        private bool isDarkMode;
        public DiskTypeWindow(bool darkMode)
        {
            InitializeComponent();
            isDarkMode = darkMode;
            ApplyTheme();
            tbStatus.Text = "Please select an option...";
        }

        public DiskTypeWindow() : this(false) { }

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
            tbStatus.Foreground = (SolidColorBrush)Resources["DarkForeground"];

            // Update button styles
            btnHDD.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnHDD.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnHDD.BorderBrush = Brushes.Gray;

            btnSSD.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnSSD.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnSSD.BorderBrush = Brushes.Gray;
        }

        private void ApplyLightTheme()
        {
            // Revert to default light theme
            this.Background = (SolidColorBrush)Resources["LightBackground"];
            MainGrid.Background = (SolidColorBrush)Resources["LightBackground"];

            // Update text colors
            tbTitle.Foreground = (SolidColorBrush)Resources["LightForeground"];
            tbStatus.Foreground = (SolidColorBrush)Resources["LightForeground"];

            // Update button styles
            btnHDD.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnHDD.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnHDD.BorderBrush = Brushes.Gray;

            btnSSD.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnSSD.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnSSD.BorderBrush = Brushes.Gray;
        }

        private void RunHDDOptimization()
        {
            try
            {
                tbStatus.Text = "Running HDD optimization...";

                // Execute commands one by one
                ExecuteCommand("fsutil behavior set memoryusage 2");
                ExecuteCommand("fsutil behavior set disablelastaccess 1");
                ExecuteCommand("fsutil behavior set disabledeletenotify 0");
                ExecuteCommand("fsutil behavior set encryptpagingfile 0");
                ExecuteCommand("fsutil behavior set mftzone 4");
                ExecuteCommand("fsutil behavior set disable8dot3 1");
                ExecuteCommand("sc config SysMain start=disabled");
                ExecuteCommand("sc stop SysMain");

                // For the complex part (registry query) - create a special method
                OptimizeHDDRegistry();

                tbStatus.Text = "HDD optimization completed!";
                MessageBox.Show("HDD optimization completed successfully!");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}");
            }
        }

        private void OptimizeHDDRegistry()
        {
            // Query the registry to get key storage devices
            Process queryProcess = new Process();
            queryProcess.StartInfo.FileName = "cmd.exe";
            queryProcess.StartInfo.Arguments = @"/C Reg.exe Query HKLM\SYSTEM\CurrentControlSet\Enum /f ""{4d36e967-e325-11ce-bfc1-08002be10318}"" /d /s | Find ""HKEY""";
            queryProcess.StartInfo.RedirectStandardOutput = true;
            queryProcess.StartInfo.UseShellExecute = false;
            queryProcess.StartInfo.CreateNoWindow = true;

            queryProcess.Start();
            string output = queryProcess.StandardOutput.ReadToEnd();
            queryProcess.WaitForExit();

            // Process each registry key found
            string[] lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string line in lines)
            {
                if (line.Contains("HKEY"))
                {
                    string registryKey = line.Trim();
                    ExecuteCommand($@"Reg.exe delete ""{registryKey}\Device Parameters\Disk"" /v UserWriteCacheSetting /f");
                    ExecuteCommand($@"Reg.exe add ""{registryKey}\Device Parameters\Disk"" /v CacheIsPowerProtected /t REG_DWORD /d 1 /f");
                }
            }
        }

        private void RunSSDOptimization()
        {
            try
            {
                tbStatus.Text = "Running SSD optimization...";

                // Execute commands one by one
                ExecuteCommand("fsutil behavior set memoryusage 2");
                ExecuteCommand("fsutil behavior set disablelastaccess 1");
                ExecuteCommand("fsutil behavior set disabledeletenotify 0");
                ExecuteCommand("fsutil behavior set encryptpagingfile 0");
                ExecuteCommand("fsutil behavior set disable8dot3 1");

                // For simpler registry commands
                ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SD\IdleState\1"" /v ""IdleExitEnergyMicroJoules"" /t REG_DWORD /d ""0"" /f");
                ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SD\IdleState\1"" /v ""IdleExitLatencyMs"" /t REG_DWORD /d ""0"" /f");
                ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SD\IdleState\1"" /v ""IdlePowerMw"" /t REG_DWORD /d ""0"" /f");
                ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SD\IdleState\1"" /v ""IdleTimeLengthMs"" /t REG_DWORD /d ""4294967295"" /f");
                ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1"" /v ""IdleExitEnergyMicroJoules"" /t REG_DWORD /d ""0"" /f");
                ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1"" /v ""IdleExitLatencyMs"" /t REG_DWORD /d ""0"" /f");
                ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1"" /v ""IdlePowerMw"" /t REG_DWORD /d ""0"" /f");
                ExecuteCommand(@"Reg.exe add ""HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\SSD\IdleState\1"" /v ""IdleTimeLengthMs"" /t REG_DWORD /d ""4294967295"" /f");

                // For the complex part (registry query) - create a special method
                OptimizeSSDRegistry();

                tbStatus.Text = "SSD optimization completed!";
                MessageBox.Show("SSD optimization completed successfully!");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}");
            }
        }

        // Method to execute regular commands
        private void ExecuteCommand(string command)
        {
            Process process = new Process();
            ProcessStartInfo startInfo = new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/C {command}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            process.StartInfo = startInfo;
            process.Start();
            process.WaitForExit();
        }

        private void OptimizeSSDRegistry()
        {
            // Query the registry to get key storage devices
            Process queryProcess = new Process();
            queryProcess.StartInfo.FileName = "cmd.exe";
            queryProcess.StartInfo.Arguments = @"/C Reg.exe Query HKLM\SYSTEM\CurrentControlSet\Enum /f ""{4d36e967-e325-11ce-bfc1-08002be10318}"" /d /s | Find ""HKEY""";
            queryProcess.StartInfo.RedirectStandardOutput = true;
            queryProcess.StartInfo.UseShellExecute = false;
            queryProcess.StartInfo.CreateNoWindow = true;

            queryProcess.Start();
            string output = queryProcess.StandardOutput.ReadToEnd();
            queryProcess.WaitForExit();

            // Process each registry key found
            string[] lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string line in lines)
            {
                if (line.Contains("HKEY"))
                {
                    string registryKey = line.Trim();
                    ExecuteCommand($@"Reg.exe add ""{registryKey}\Device Parameters\Disk"" /v UserWriteCacheSetting /t REG_DWORD /d 1 /f");
                    ExecuteCommand($@"Reg.exe add ""{registryKey}\Device Parameters\Disk"" /v CacheIsPowerProtected /t REG_DWORD /d 1 /f");
                }
            }
        }
            
        private void BtnHDD_Click(object sender, RoutedEventArgs e)
        {
            RunHDDOptimization();
        }

        private void BtnSSD_Click(object sender, RoutedEventArgs e)
        {
            RunSSDOptimization();
        }
    }
}