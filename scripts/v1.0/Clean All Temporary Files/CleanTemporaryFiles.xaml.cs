using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;

namespace TGOptiv10
{
    public partial class CleanTemporaryFiles : Window
    {
        private bool isDarkMode;
        private WebClient webClient;
        private string downloadUrl;
        private string fileName;
        private string tgFolder = @"C:\TGOptiResources\CleanAllTemporaryFiles\";
        private string batchFileName = "CleanAllTempFiles.bat";

        public CleanTemporaryFiles(bool darkMode)
        {
            InitializeComponent();
            isDarkMode = darkMode;
            ApplyTheme();
            tbStatus.Text = "Click 'Start Cleaning' to begin...";
            pbDownload.Visibility = Visibility.Hidden;
        }

        public CleanTemporaryFiles() : this(false) { }

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
            DownloadCleanScript();
        }

        private void DownloadCleanScript()
        {
            try
            {
                // Create TGR folder
                if (!Directory.Exists(tgFolder))
                    Directory.CreateDirectory(tgFolder);

                string filePath = Path.Combine(tgFolder, batchFileName);

                // Use the provided batch content
                string batchContent = @"echo off
cls
del /s /f /q c:\windows\temp.
del /s /f /q C:\WINDOWS\Prefetch
del /s /f /q %temp%.
del /s /f /q %systemdrive%\*.tmp
del /s /f /q %systemdrive%\*._mp
del /s /f /q %systemdrive%\*.log
del /s /f /q %systemdrive%\*.gid
del /s /f /q %systemdrive%\*.chk
del /s /f /q %systemdrive%\*.old
del /s /f /q %systemdrive%\recycled\*.*
del /s /f /q %systemdrive%\$Recycle.Bin\*.*
del /s /f /q %windir%\*.bak
del /s /f /q %windir%\prefetch\*.*
del /s /f /q %LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db
del /s /f /q %LocalAppData%\Microsoft\Windows\Explorer\*.db
del /f /q %SystemRoot%\Logs\CBS\CBS.log
del /f /q %SystemRoot%\Logs\DISM\DISM.log
cls
net stop wuauserv
net stop UsoSvc
net stop bits
net stop dosvc
rd /s /q C:\Windows\SoftwareDistribution
md C:\Windows\SoftwareDistribution
cls
cd/
del *.log /a /s /q /f
cls
POWERSHELL ""Optimize-Volume -DriveLetter C -ReTrim""
exit";

                File.WriteAllText(filePath, batchContent);

                // Run directly after creating the file
                tbStatus.Text = "Batch file created!";
                RunCleanupScript(filePath);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error creating batch file: {ex.Message}");
            }
        }

        private void RunCleanupScript(string batchFilePath)
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

                    tbStatus.Text = "Cleaning all temporary files...";
                    ShowInstructions();
                }
                else
                {
                    MessageBox.Show("Batch file not found!");
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error running cleanup script: {ex.Message}");
            }
        }

        private void ShowInstructions()
        {
            MessageBox.Show("Temporary files cleanup is in progress:\n\n" +
                          "1. The script will run automatically\n" +
                          "2. It will deleting all the temporary files\n" +
                          "3. It will also deleting Windows Update temporary files\n" +
                          "4. It will also defragmenting the C drive\n\n" +
                          "It will be done and closing automatically when done.",
                          "Temporary Files Cleanup",
                          MessageBoxButton.OK,
                          MessageBoxImage.Information);

            // Wait for the process to complete
            WaitForCleanupToComplete();
        }

        private void WaitForCleanupToComplete()
        {
            var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            timer.Tick += (s, args) =>
            {
                // Check if the cleanup process is still running or not
                bool isCleanupRunning = false;
                Process[] processes = Process.GetProcessesByName("cmd");
                foreach (Process p in processes)
                {
                    try
                    {
                        if (p.MainWindowTitle.Contains("cmd"))
                        {
                            isCleanupRunning = true;
                            break;
                        }
                    }
                    catch { /* Ignore inaccessible processes */ }
                }

                if (!isCleanupRunning)
                {
                    timer.Stop();
                    tbStatus.Text = "Temporary files cleanup completed!";
                    MessageBox.Show("Temporary files cleanup completed successfully!");
                    this.Close();
                }
            };
            timer.Start();
        }
    }
}