using disIntelLib;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using GitVersionInfo;

// General Information about an assembly is controlled through the following 
// set of attributes. Change these attribute values to modify the information
// associated with an assembly.
[assembly: AssemblyTitle(VersionInfo.GIT_APPNAME)]
[assembly: AssemblyDescription("description")]
#if DEBUG
[assembly: AssemblyConfiguration("debug")]
#else
[assembly: AssemblyConfiguration("")]
#endif
[assembly: AssemblyCompany("Mark Ogden")]
[assembly: AssemblyProduct(VersionInfo.GIT_APPNAME)]
[assembly: AssemblyCopyright("(C)" + VersionInfo.GIT_YEAR + " Mark Ogden")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]

[assembly: AssemblyInformationalVersion(VersionInfo.GIT_VERSION )]

// Setting ComVisible to false makes the types in this assembly not visible 
// to COM components.  If you need to access a type in this assembly from 
// COM, set the ComVisible attribute to true on that type.
[assembly: ComVisible(false)]

// The following GUID is for the ID of the typelib if this project is exposed to COM
// replace the following with suitable Guid
[assembly: Guid("d5b27897-00c2-424f-afa1-b49eb5642ffc")]

[assembly: AssemblyVersion(VersionInfo.GIT_VERSION_RC)]
[assembly: AssemblyFileVersion(VersionInfo.GIT_VERSION_RC)]
