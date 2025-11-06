# تفعيل MCP و VS Code

## الخطوات:

```powershell
# من جذر المشروع
cd c:\Users\user\Music\WawApp\root
.\tools\setup_mcp.ps1
```

## الملفات المُفعّلة:

- `.mcp/servers.json` - خادمين أساسيين (filesystem + git)
- `.mcp/ignore.txt` - استبعاد المسارات الثقيلة
- `.vscode/settings.json` - تقليل فهرسة VS Code
- `.git-hooks/pre-commit.ps1` - حارس المعمارية

## التحقق:

```powershell
# فحص المعمارية يدوياً
.\tools\arch_guard.ps1
```
