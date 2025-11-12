using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Windows;
using System.Windows.Threading;
using System.Windows.Media;

namespace TGOptiv10
{
    public partial class StartupOptimizationWindow : Window
    {
        private bool isDarkMode;
        private WebClient webClient;
        private string downloadUrl;
        private string fileName;
        private string tgFolder = @"C:\TGOptiResources\Autoruns\";

        public StartupOptimizationWindow(bool darkMode)
        {
            InitializeComponent();
            isDarkMode = darkMode;
            ApplyTheme();
            tbStatus.Text = "Click 'Start Optimization' to begin...";
            pbDownload.Visibility = Visibility.Hidden; // make the progress bar hidden initially
        }

        public StartupOptimizationWindow() : this(false) { }

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

            // Update textbox style
            pbDownload.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            pbDownload.BorderBrush = Brushes.Gray;
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

            // Update textbox style
            pbDownload.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            pbDownload.BorderBrush = Brushes.Gray;
        }

        private void CheckSystemType()
        {
            bool is64Bit = Environment.Is64BitOperatingSystem;
            downloadUrl = is64Bit ?
                "https://download.sysinternals.com/files/Autoruns.zip" :
                "https://download.sysinternals.com/files/Autoruns.zip";

            fileName = is64Bit ? "Autoruns64.exe" : "Autoruns.exe";
            tbStatus.Text = is64Bit ?
                "Downloading Autoruns64 for 64-bit system..." :
                "Downloading Autoruns for 32-bit system...";
        }

        private void BtnStart_Click(object sender, RoutedEventArgs e)
        {
            btnStart.Visibility = Visibility.Collapsed;
            pbDownload.Visibility = Visibility.Visible; // show progress bar
            CheckSystemType(); // now check system type and set URLs
            DownloadAutoruns();
        }

        private void DownloadAutoruns()
        {
            try
            {
                // Create TGR folder
                if (!Directory.Exists(tgFolder))
                    Directory.CreateDirectory(tgFolder);

                string filePath = Path.Combine(tgFolder, "Autoruns.zip");

                webClient = new WebClient();
                webClient.DownloadProgressChanged += WebClient_DownloadProgressChanged;
                webClient.DownloadFileCompleted += WebClient_DownloadFileCompleted;
                webClient.DownloadFileAsync(new Uri(downloadUrl), filePath);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Download error: {ex.Message}");
            }
        }

        private void WebClient_DownloadProgressChanged(object sender, DownloadProgressChangedEventArgs e)
        {
            pbDownload.Value = e.ProgressPercentage;
            tbStatus.Text = $"Downloading... {e.ProgressPercentage}%";
        }

        private void WebClient_DownloadFileCompleted(object sender, System.ComponentModel.AsyncCompletedEventArgs e)
        {
            if (e.Error == null)
            {
                tbStatus.Text = "Download completed! Extracting...";

                // Extract and run Autoruns
                ExtractAndRunAutoruns();
            }
            else
            {
                MessageBox.Show($"Download failed: {e.Error.Message}");
            }
        }

        private void ExtractAndRunAutoruns()
        {
            try
            {
                string zipPath = Path.Combine(tgFolder, "Autoruns.zip");
                string extractPath = tgFolder;

                // Extract ZIP (using PowerShell since .NET Framework doesn't have built-in ZIP)
                string extractScript = $@"
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory('{zipPath}', '{extractPath}')
                    Remove-Item '{zipPath}' -Force
                ";

                Process.Start(new ProcessStartInfo
                {
                    FileName = "powershell",
                    Arguments = $"-Command \"{extractScript}\"",
                    UseShellExecute = true
                });

                // Wait a bit for extraction
                var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3) };
                timer.Tick += (s, args) =>
                {
                    timer.Stop();
                    RunAutoruns();
                };
                timer.Start();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Extraction error: {ex.Message}");
            }
        }

        private void RunAutoruns()
        {
            try
            {
                string autorunsPath = Path.Combine(tgFolder, fileName);

                if (File.Exists(autorunsPath))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = autorunsPath,
                        UseShellExecute = true
                    });

                    tbStatus.Text = "Autoruns is running!";
                    ShowInstructions();
                }
                else
                {
                    MessageBox.Show("Autoruns file not found!");
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error running Autoruns: {ex.Message}");
            }
        }

        private void ShowInstructions()
        {
            MessageBox.Show("To disable unnecessary startup programs:\n\n" +
                          "1. Go to the 'Logon' tab\n" +
                          "2. Uncheck programs you want to disable\n" +
                          "3. Close Autoruns when finished\n\n" +
                          "You will return to main menu automatically.",
                          "Startup Optimization Instructions",
                          MessageBoxButton.OK,
                          MessageBoxImage.Information);

            // Wait for Autoruns to close and return to main window
            WaitForAutorunsToClose();
        }

        private void WaitForAutorunsToClose()
        {
            var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            timer.Tick += (s, args) =>
            {
                if (IsAutorunsRunning()) return;

                timer.Stop();
                tbStatus.Text = "Startup optimization completed!";
                MessageBox.Show("Startup optimization completed successfully!");
                this.Close();
            };
            timer.Start();
        }

        private bool IsAutorunsRunning()
        {
            Process[] processes = Process.GetProcesses();
            return Array.Exists(processes, p =>
                p.ProcessName.Equals("Autoruns", StringComparison.OrdinalIgnoreCase) ||
                p.ProcessName.Equals("Autoruns64", StringComparison.OrdinalIgnoreCase));
        }
    }
}