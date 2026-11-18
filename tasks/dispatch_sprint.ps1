# E:\ChessToDie\tasks\dispatch_sprint.ps1
$ErrorActionPreference = "Continue"

Write-Host "=== Auto-Dispatch Sprint 1 (Ag2 & Ag3) ==="

$promptAg2 = 'Đọc kỹ src/GEMINI.md, design/GDD_Core.md, tasks/code_spec.md và tasks/ag2_prompt.txt. Triển khai toàn bộ 11 module GDScript chuẩn typed và test runner vào src/ theo đúng spec. Báo cáo hoàn tất.'
$promptAg3 = 'Đọc kỹ assets/GEMINI.md, design/GDD_Core.md, tasks/art_spec.md và tasks/ag3_prompt.txt. Tạo và xuất toàn bộ 41 tài nguyên vào assets/ và cập nhật assets/manifest.json theo đúng spec. Báo cáo hoàn tất.'

# Start Ag2 (Coder)
$p2 = Start-Process -FilePath "cmd.exe" -ArgumentList "/c agy --dangerously-skip-permissions -p `"$promptAg2`" > tasks\ag2.log 2>&1" -PassThru -NoNewWindow

# Start Ag3 (Artist)
$p3 = Start-Process -FilePath "cmd.exe" -ArgumentList "/c agy --dangerously-skip-permissions -p `"$promptAg3`" > tasks\ag3.log 2>&1" -PassThru -NoNewWindow

Write-Host "Ag2 PID: $($p2.Id), Ag3 PID: $($p3.Id)"

# Wait for both processes to complete
Wait-Process -Id $p2.Id, $p3.Id

Write-Host "=== Auto-Dispatch Sprint 1 Finished ==="
