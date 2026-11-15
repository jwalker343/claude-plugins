param(
    [string]$Title = "Claude Code",
    [string]$Body = "Needs your attention"
)

function ConvertTo-XmlSafeString {
    param([string]$Text)

    $Text = $Text -replace '&', '&amp;'
    $Text = $Text -replace '<', '&lt;'
    $Text = $Text -replace '>', '&gt;'
    $Text = $Text -replace '"', '&quot;'
    $Text = $Text -replace "'", '&apos;'

    return $Text
}

function Invoke-ClaudeToast {
    param(
        [string]$Title,
        [string]$Body
    )

    try {
        $ErrorActionPreference = 'Stop'

        # Load WinRT types
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

        # Use Windows PowerShell's registered AUMID
        $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

        # XML-escape user input to prevent injection
        $SafeTitle = ConvertTo-XmlSafeString -Text $Title
        $SafeBody = ConvertTo-XmlSafeString -Text $Body

        # Build toast XML with escaped content
        $ToastXml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$SafeTitle</text>
            <text>$SafeBody</text>
        </binding>
    </visual>
</toast>
"@

        # Load XML and create notification
        $XmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $XmlDoc.LoadXml($ToastXml)

        $Toast = New-Object Windows.UI.Notifications.ToastNotification -ArgumentList $XmlDoc
        $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
        $Notifier.Show($Toast)
    }
    catch {
        # Fail silently - never block, never throw
    }

    exit 0
}

Invoke-ClaudeToast -Title $Title -Body $Body
