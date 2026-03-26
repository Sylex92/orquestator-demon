using DaemonPlatform.Contracts.Configuration;
using DaemonAdmin.Web.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: false);

var nodeSettingsFile = Environment.GetEnvironmentVariable("DAEMON_NODE_SETTINGS_FILE");
if (!string.IsNullOrWhiteSpace(nodeSettingsFile))
{
    builder.Configuration.AddJsonFile(nodeSettingsFile, optional: false, reloadOnChange: false);
}

builder.Services.Configure<AdminApiOptions>(builder.Configuration.GetSection(AdminApiOptions.SectionName));
builder.Services.AddHttpClient<IAdminApiClient, AdminApiClient>((serviceProvider, client) =>
{
    var options = serviceProvider.GetRequiredService<Microsoft.Extensions.Options.IOptions<AdminApiOptions>>().Value;
    client.BaseAddress = new Uri(options.BaseUrl);
});
builder.Services.AddControllersWithViews();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.MapControllerRoute(name: "default", pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
