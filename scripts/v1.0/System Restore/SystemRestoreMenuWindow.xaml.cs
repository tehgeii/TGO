using System;
using System.Diagnostics;
using System.IO;
using System.Net.NetworkInformation;
using System.Windows;
using System.Windows.Threading;
using System.Windows.Controls;
using System.Windows.Media;

namespace TGOptiv10
{
    public partial class SystemRestoreMenuWindow : Window
    {
        private bool isDarkMode;

        public SystemRestoreMenuWindow(bool darkMode)
        {
            InitializeComponent();
            isDarkMode = darkMode;
            ApplyTheme();
            tbStatus.Text = "Please select an option...";
        }

        public SystemRestoreMenuWindow() : this(false) { }

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
            btnCreateRestorePoint.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnCreateRestorePoint.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnCreateRestorePoint.BorderBrush = Brushes.Gray;

            btnOpenSystemRestore.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnOpenSystemRestore.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnOpenSystemRestore.BorderBrush = Brushes.Gray;
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
            btnCreateRestorePoint.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnCreateRestorePoint.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnCreateRestorePoint.BorderBrush = Brushes.Gray;

            btnOpenSystemRestore.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnOpenSystemRestore.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnOpenSystemRestore.BorderBrush = Brushes.Gray;
        }

        private void BtnCreateRestorePoint_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Create a system restore point using PowerShell
                string command = @"powershell -Command ""Checkpoint-Computer -Description 'TGOpti Restore Point' -RestorePointType MODIFY_SETTINGS""";

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = $"/c {command}",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using (Process process = new Process())
                {
                    process.StartInfo = psi;
                    process.Start();

                    // Read output and error (if any)
                    string output = process.StandardOutput.ReadToEnd();
                    string error = process.StandardError.ReadToEnd();

                    process.WaitForExit();

                    if (process.ExitCode == 0)
                    {
                        MessageBox.Show("Restore point created successfully!");
                    }
                    else
                    {
                        MessageBox.Show($"Error creating restore point: {error}");
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error creating restore point: {ex.Message}");
            }
        }

        private void BtnOpenSystemRestore_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                tbStatus.Text = "Checking System Restore availability...";

                // try to locate rstrui.exe in common paths
                string[] possiblePaths = {
            Path.Combine(Environment.GetEnvironmentVariable("SystemRoot"), "System32", "rstrui.exe"),
            Path.Combine(Environment.GetEnvironmentVariable("SystemRoot"), "SysNative", "rstrui.exe"), // For 64-bit
            Path.Combine(Environment.GetEnvironmentVariable("SystemRoot"), "System32", "sysdm.cpl"), // Alternative via Control Panel
            "rstrui.exe" // Try without path, relying on system PATH
        };

                string foundPath = null;
                foreach (string path in possiblePaths)
                {
                    if (File.Exists(path))
                    {
                        foundPath = path;
                        break;
                    }
                }

                if (foundPath != null)
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = foundPath,
                        Verb = "runas",
                        UseShellExecute = true
                    };

                    Process.Start(psi);
                    tbStatus.Text = "System Restore is opening...";
                    ShowInstructions();
                }
                else
                {
                    // Alternative: Open System Properties -> System Protection tab
                    TryAlternativeSystemRestore();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}\n\nPlease run as Administrator.");
            }
        }

        private void TryAlternativeSystemRestore()
        {
            try
            {
                // Try open System Properties -> System Protection tab
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "systempropertiesprotection",
                    Verb = "runas",
                    UseShellExecute = true
                };

                Process.Start(psi);
                tbStatus.Text = "Opening System Protection settings...";
                MessageBox.Show("System Restore (rstrui.exe) not found.\n\nOpening System Protection settings instead.\n\nPlease enable System Restore from there.",
                                "TGOpti - Info", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch
            {
                // Final fallback: Open Control Panel
                try
                {
                    Process.Start("control.exe", "system");
                    MessageBox.Show("Please enable System Restore from Control Panel → System → System Protection.",
                                    "TGOpti - Info", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"System Restore is not available on your system.\n\nError: {ex.Message}",
                                    "TGOpti - Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void ShowInstructions()
        {
            MessageBox.Show("System Restore is now opening:\n\n" +
                          "1. The System Restore window will appear\n" +
                          "2. Follow the instructions in the System Restore window\n" +
                          "3. Select a restore point if available\n" +
                          "4. Confirm to start the restoration process\n\n" +
                          "Your computer will restart during the process.",
                          "System Restore",
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
                // Checking if rstrui.exe is still running
                bool isProcessRunning = false;
                Process[] processes = Process.GetProcessesByName("rstrui.exe");
                foreach (Process p in processes)
                {
                    try
                    {
                        if (!p.HasExited)
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
                    tbStatus.Text = "System Restore process completed!";
                    MessageBox.Show("System Restore process has been completed.");
                }
            };
            timer.Start();
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }
    }
}