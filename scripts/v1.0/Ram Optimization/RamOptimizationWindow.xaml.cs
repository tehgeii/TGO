using System;
using System.Diagnostics;
using System.Windows;
using System.IO;
using System.Windows.Controls;
using System.Windows.Media;
using System.Collections.Generic;
using System.Net.NetworkInformation;
using System.Windows.Threading;

namespace TGOptiv10
{
    public partial class RamOptimizationWindow : Window
    {
        private bool isDarkMode;

        public RamOptimizationWindow(bool darkMode)
        {
            InitializeComponent();
            isDarkMode = darkMode;
            ApplyTheme();
            tbStatus.Text = "Please select an option...";
        }

        public RamOptimizationWindow() : this(false) { }

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
            tbSubTitle.Foreground = (SolidColorBrush)Resources["DarkForeground"];
            txtSelect.Foreground = (SolidColorBrush)Resources["DarkForeground"];
            tbStatus.Foreground = (SolidColorBrush)Resources["DarkForeground"];

            // Update button styles
            btnOptimize.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnOptimize.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnOptimize.BorderBrush = Brushes.Gray;

            btnRevert.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            btnRevert.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            btnRevert.BorderBrush = Brushes.Gray;

            r2gb.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            r2gb.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            r2gb.BorderBrush = Brushes.Gray;

            r4gb.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            r4gb.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            r4gb.BorderBrush = Brushes.Gray;

            r8gb.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            r8gb.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            r8gb.BorderBrush = Brushes.Gray;

            r16gb.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            r16gb.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            r16gb.BorderBrush = Brushes.Gray;

            r24gb.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            r24gb.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            r24gb.BorderBrush = Brushes.Gray;

            r32gb.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            r32gb.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            r32gb.BorderBrush = Brushes.Gray;

            r64gb.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            r64gb.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            r64gb.BorderBrush = Brushes.Gray;

            r128gb.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            r128gb.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            r128gb.BorderBrush = Brushes.Gray;

            // Update textbox style
            txtRamSize.Background = (SolidColorBrush)Resources["DarkButtonBackground"];
            txtRamSize.Foreground = (SolidColorBrush)Resources["DarkButtonForeground"];
            txtRamSize.BorderBrush = Brushes.Gray;
        }

        private void ApplyLightTheme()
        {
            // Revert to default light theme
            this.Background = (SolidColorBrush)Resources["LightBackground"];
            MainGrid.Background = (SolidColorBrush)Resources["LightBackground"];

            // Update text colors
            tbTitle.Foreground = (SolidColorBrush)Resources["LightForeground"];
            tbSubTitle.Foreground = (SolidColorBrush)Resources["LightForeground"];
            txtSelect.Foreground = (SolidColorBrush)Resources["LightForeground"];
            tbStatus.Foreground = (SolidColorBrush)Resources["LightForeground"];

            // Update button styles
            btnOptimize.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnOptimize.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnOptimize.BorderBrush = Brushes.Gray;

            btnRevert.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            btnRevert.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            btnRevert.BorderBrush = Brushes.Gray;

            r2gb.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            r2gb.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            r2gb.BorderBrush = Brushes.Gray;

            r4gb.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            r4gb.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            r4gb.BorderBrush = Brushes.Gray;

            r8gb.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            r8gb.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            r8gb.BorderBrush = Brushes.Gray;

            r16gb.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            r16gb.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            r16gb.BorderBrush = Brushes.Gray;

            r24gb.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            r24gb.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            r24gb.BorderBrush = Brushes.Gray;

            r32gb.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            r32gb.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            r32gb.BorderBrush = Brushes.Gray;

            r64gb.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            r64gb.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            r64gb.BorderBrush = Brushes.Gray;

            r128gb.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            r128gb.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            r128gb.BorderBrush = Brushes.Gray;

            // Update textbox style
            txtRamSize.Background = (SolidColorBrush)Resources["LightButtonBackground"];
            txtRamSize.Foreground = (SolidColorBrush)Resources["LightButtonForeground"];
            txtRamSize.BorderBrush = Brushes.Gray;
        }

        // Adding methods for each button click to set RAM size
        private void Btn2GB_Click(object sender, RoutedEventArgs e)
        {
            txtRamSize.Text = "2";
        }
        private void Btn4GB_Click(object sender, RoutedEventArgs e)
        {
            txtRamSize.Text = "4";
        }
        private void Btn8GB_Click(object sender, RoutedEventArgs e)
        {
            txtRamSize.Text = "8";
        }
        private void Btn16GB_Click(object sender, RoutedEventArgs e)
        {
            txtRamSize.Text = "16";
        }
        private void Btn24GB_Click(object sender, RoutedEventArgs e)
        {
            txtRamSize.Text = "24";
        }
        private void Btn32GB_Click(object sender, RoutedEventArgs e)
        {
            txtRamSize.Text = "32";
        }
        private void Btn64GB_Click(object sender, RoutedEventArgs e)
        {
            txtRamSize.Text = "64";
        }
        private void Btn128GB_Click(object sender, RoutedEventArgs e)
        {
            txtRamSize.Text = "128";
        }

        private void RunRamOptimization(string ramSize)
        {
            try
            {
                if (!int.TryParse(ramSize, out int ramGB))
                {
                    MessageBox.Show("Please enter a valid number for RAM size!");
                    return;
                }

                tbStatus.Text = "Running RAM optimization...";

                string script = $@"
                # Set SvcHostSplitThreshold
                Set-ItemProperty -Path 'HKLM:\SYSTEM\ControlSet001\Control' -Name 'SvcHostSplitThresholdInKB' -Value {ramGB * 1024 * 1024} -Type DWord -Force
    
                # Set LargeSystemCache based on RAM size
                if ({ramGB} -ge 16) {{
                    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 1 -Type DWord -Force
                    try {{
                        Disable-MMAgent -MemoryCompression -ErrorAction Stop
                    }} catch {{
                        Write-Warning ""Memory Compression is already disabled or not available""
                    }}
                    Write-Host 'Optimized for {ramGB}GB RAM - Enabled Large System Cache and Disabled Memory Compression'
                }} else {{
                    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 0 -Type DWord -Force
                    try {{
                        Enable-MMAgent -MemoryCompression -ErrorAction Stop
                    }} catch {{
                        Write-Warning ""Memory Compression is already enabled or not available""
                    }}
                    Write-Host 'Optimized for {ramGB}GB RAM - Disabled Large System Cache and Enabled Memory Compression'
                }}
    
                Write-Host 'RAM optimization completed for {ramGB}GB!'
                ";

                Process.Start(new ProcessStartInfo
                {
                    FileName = "powershell",
                    Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{script}\"",
                    Verb = "runas",
                    UseShellExecute = true,
                    CreateNoWindow = true
                });

                tbStatus.Text = $"RAM optimization completed for {ramGB}GB!";
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}");
            }
        }

        private void RevertRamOptimization()
        {
            try
            {
                tbStatus.Text = "Reverting RAM optimization...";

                string script = @"
                    # Revert to Default
                    Set-ItemProperty -Path 'HKLM:\SYSTEM\ControlSet001\Control' -Name 'SvcHostSplitThresholdInKB' -Value 3670016 -Type DWord -Force
                    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 0 -Type DWord -Force
                    try {{
                        Enable-MMAgent -MemoryCompression -ErrorAction Stop
                    }} catch {{
                        Write-Warning ""Memory Compression is already enabled or not available""
                    }}
                    Write-Host 'RAM settings reverted to default!'
                ";

                Process.Start(new ProcessStartInfo
                {
                    FileName = "powershell",
                    Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{script}\"",
                    Verb = "runas",
                    UseShellExecute = true,
                    CreateNoWindow = true
                });

                tbStatus.Text = "RAM settings reverted to default!";
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error: {ex.Message}");
            }
        }

        private void BtnOptimize_Click(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrEmpty(txtRamSize.Text))
            {
                RunRamOptimization(txtRamSize.Text);
            }
            else
            {
                MessageBox.Show("Please enter RAM size in GB");
            }
        }

        private void BtnRevert_Click(object sender, RoutedEventArgs e)
        {
            RevertRamOptimization();
        }

        // Helper method to find visual children
        private static IEnumerable<T> FindVisualChildren<T>(DependencyObject depObj) where T : DependencyObject
        {
            if (depObj != null)
            {
                for (int i = 0; i < VisualTreeHelper.GetChildrenCount(depObj); i++)
                {
                    DependencyObject child = VisualTreeHelper.GetChild(depObj, i);
                    if (child != null && child is T)
                    {
                        yield return (T)child;
                    }

                    foreach (T childOfChild in FindVisualChildren<T>(child))
                    {
                        yield return childOfChild;
                    }
                }
            }
        }
    }
}