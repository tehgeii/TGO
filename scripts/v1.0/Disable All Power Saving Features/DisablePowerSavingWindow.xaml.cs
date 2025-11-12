using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;

namespace TGOptiv10
{
    public partial class DisablePowerSavingWindow : Window
    {
        private bool isDarkMode;
        private string tgFolder = @"C:\TGOptiResources\DisablePowerSaving\";
        private string batchFileName = "DisablePowerSaving.bat";

        public DisablePowerSavingWindow(bool darkMode)
        {
            InitializeComponent();
            isDarkMode = darkMode;
            ApplyTheme();
            tbStatus.Text = "Click 'Start Disabling' to begin...";
            pbDownload.Visibility = Visibility.Hidden;
        }

        public DisablePowerSavingWindow() : this(false) { }

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
            tbStatus.Foreground = (SolidColorBrush)Resources["DarkForeground"];

            // Update button styles
            btnStart.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnStart.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnStart.BorderBrush = Brushes.Gray;
        }

        private void ApplyLightTheme()
        {
            // Revert to default light theme
            this.Background = (SolidColorBrush)Resources["LightBackground"];
            MainGrid.Background = (SolidColorBrush)Resources["LightBackground"];

            // Update text colors
            tbStatus.Foreground = (SolidColorBrush)Resources["LightForeground"];

            // Update button styles
            btnStart.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnStart.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnStart.BorderBrush = Brushes.Gray;
        }

        private void BtnStart_Click(object sender, RoutedEventArgs e)
        {
            btnStart.Visibility = Visibility.Collapsed;
            pbDownload.Visibility = Visibility.Collapsed;
            CreateAndRunPowerScript();
        }

        private void CreateAndRunPowerScript()
        {
            try
            {
                // Create TGR folder
                if (!Directory.Exists(tgFolder))
                    Directory.CreateDirectory(tgFolder);

                string filePath = Path.Combine(tgFolder, batchFileName);

                // Use the provided batch content
                string batchContent = @"@echo off
cls
POWERSHELL ""$devices = Get-WmiObject Win32_PnPEntity; $powerMgmt = Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi; foreach ($p in $powerMgmt){$IN = $p.InstanceName.ToUpper(); foreach ($h in $devices){$PNPDI = $h.PNPDeviceID; if ($IN -like \""*$PNPDI*\""){$p.enable = $False; $p.psbase.put()}}}""
exit";

                File.WriteAllText(filePath, batchContent);

                // Run directly after creating the file
                tbStatus.Text = "Power management script created!";
                RunPowerScript(filePath);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error creating batch file: {ex.Message}");
            }
        }

        private void RunPowerScript(string batchFilePath)
        {
            try
            {
                if (File.Exists(batchFilePath))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = batchFilePath,
                        UseShellExecute = true,
                        Verb = "runas" // Run as administrator
                    });

                    tbStatus.Text = "Disabling power management features...";
                    ShowInstructions();
                }
                else
                {
                    MessageBox.Show("Batch file not found!");
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error running power script: {ex.Message}");
            }
        }

        private void ShowInstructions()
        {
            MessageBox.Show("Power management disabling is in progress:\n\n" +
                          "1. The script will run automatically\n" +
                          "2. It will disable all power saving for all devices\n" +
                          "3. Please wait for the process to complete\n\n" +
                          "This will improve performance but may increase power consumption.",
                          "Disable Power Saving Features",
                          MessageBoxButton.OK,
                          MessageBoxImage.Information);

            // Wait for the process to complete
            WaitForProcessToComplete();
        }

        private void WaitForProcessToComplete()
        {
            var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            timer.Tick += (s, args) =>
            {
                // Check if the cleanup process is still running or not
                bool isProcessRunning = false;
                Process[] processes = Process.GetProcessesByName("cmd");
                foreach (Process p in processes)
                {
                    try
                    {
                        if (p.MainWindowTitle.Contains("cmd"))
                        {
                            isProcessRunning = true;
                            break;
                        }
                    }
                    catch { /* Ignore inaccessible processes */ }
                }

                if (!isProcessRunning)
                {
                    timer.Stop();
                    tbStatus.Text = "Power management disabled successfully!";
                    MessageBox.Show("All power saving features have been disabled successfully!");
                    this.Close();
                }
            };
            timer.Start();
        }
    }
}