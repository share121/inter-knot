const fs = require("fs");
const p = require("path");

const start = `<?xml version="1.0" encoding="windows-1252"?>
<>
  <InputFile>${p.join(
    __dirname,
    "./build/windows/x64/runner/Release/inter_knot.exe"
  )}</InputFile>
  <OutputFile>${p.join(
    __dirname,
    "inter_knot_windows_x64_boxed.exe"
  )}</OutputFile>
  <Files>
    <Enabled>True</Enabled>
    <DeleteExtractedOnExit>True</DeleteExtractedOnExit>
    <CompressFiles>True</CompressFiles>
    <Files>
      <File>
        <Type>3</Type>
        <Name>%DEFAULT FOLDER%</Name>
        <Action>0</Action>
        <OverwriteDateTime>False</OverwriteDateTime>
        <OverwriteAttributes>False</OverwriteAttributes>
        <HideFromDialogs>0</HideFromDialogs>
        <Files>`;

const end = `</Files>
      </File>
    </Files>
  </Files>
  <Registries>
    <Enabled>False</Enabled>
    <Registries>
      <Registry>
        <Type>1</Type>
        <Virtual>True</Virtual>
        <Name>Classes</Name>
        <ValueType>0</ValueType>
        <Value/>
        <Registries/>
      </Registry>
      <Registry>
        <Type>1</Type>
        <Virtual>True</Virtual>
        <Name>User</Name>
        <ValueType>0</ValueType>
        <Value/>
        <Registries/>
      </Registry>
      <Registry>
        <Type>1</Type>
        <Virtual>True</Virtual>
        <Name>Machine</Name>
        <ValueType>0</ValueType>
        <Value/>
        <Registries/>
      </Registry>
      <Registry>
        <Type>1</Type>
        <Virtual>True</Virtual>
        <Name>Users</Name>
        <ValueType>0</ValueType>
        <Value/>
        <Registries/>
      </Registry>
      <Registry>
        <Type>1</Type>
        <Virtual>True</Virtual>
        <Name>Config</Name>
        <ValueType>0</ValueType>
        <Value/>
        <Registries/>
      </Registry>
    </Registries>
  </Registries>
  <Packaging>
    <Enabled>False</Enabled>
  </Packaging>
  <Options>
    <ShareVirtualSystem>False</ShareVirtualSystem>
    <MapExecutableWithTemporaryFile>True</MapExecutableWithTemporaryFile>
    <TemporaryFileMask/>
    <AllowRunningOfVirtualExeFiles>True</AllowRunningOfVirtualExeFiles>
    <ProcessesOfAnyPlatforms>False</ProcessesOfAnyPlatforms>
  </Options>
  <Storage>
    <Files>
      <Enabled>False</Enabled>
      <Folder>%DEFAULT FOLDER%\\</Folder>
      <RandomFileNames>False</RandomFileNames>
      <EncryptContent>False</EncryptContent>
    </Files>
  </Storage>
</>
`;
function build(path) {
  let t = "";
  fs.readdirSync(path, { withFileTypes: true }).forEach((file) => {
    if (file.isFile() && file.name != "inter_knot.exe") {
      t += `<File><Type>2</Type><Name>${file.name}</Name><File>${p.join(
        file.parentPath,
        file.name
      )}</File><ActiveX>False</ActiveX><ActiveXInstall>False</ActiveXInstall><Action>0</Action><OverwriteDateTime>False</OverwriteDateTime><OverwriteAttributes>False</OverwriteAttributes><PassCommandLine>False</PassCommandLine><HideFromDialogs>0</HideFromDialogs></File>`;
    } else if (file.isDirectory()) {
      t += `<File><Type>3</Type><Name>${
        file.name
      }</Name><Action>0</Action><OverwriteDateTime>False</OverwriteDateTime><OverwriteAttributes>False</OverwriteAttributes><HideFromDialogs>0</HideFromDialogs><Files>${build(
        p.join(path, file.name)
      )}</Files></File>`;
    }
  });
  return t;
}
const res = build(
  p.join(__dirname, ".\\build\\windows\\x64\\runner\\Release\\")
);
fs.writeFileSync(p.join(__dirname, "pack.evb"), start + res + end, "utf8");
