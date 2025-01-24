using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using NLog.Web;
using RareBooksService.Common.Models;            // <-- ��� YandexCloudSettings
using RareBooksService.Data;
using RareBooksService.Data.Interfaces;
using RareBooksService.Data.Services;
using RareBooksService.Parser;
using RareBooksService.Parser.Services;
using RareBooksService.WebApi.Services;
using Stripe;
using System.Security.Claims;
using System.Text;
using Yandex.Cloud.Generated;

namespace RareBooksService.WebApi
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var logger = NLogBuilder.ConfigureNLog("nlog.config").GetCurrentClassLogger();
            logger.Debug("init main");
            try
            {
                var builder = WebApplication.CreateBuilder(args);

                // ������� ��������� ����������� ����� � ���������� NLog
                builder.Logging.ClearProviders();
                builder.Host.UseNLog();

                // 1) ��������� �����������
                builder.Services.AddControllers();

                // 2) ��������� DbContext
                builder.Services.AddSingleton<NullToZeroMaterializationInterceptor>();
                builder.Services.AddDbContext<RegularBaseBooksContext>((serviceProvider, options) =>
                {
                    var interceptor = serviceProvider.GetRequiredService<NullToZeroMaterializationInterceptor>();
                    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"));
                    options.AddInterceptors(interceptor);
                });

                // 3) Identity
                builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
                    .AddEntityFrameworkStores<RegularBaseBooksContext>()
                    .AddDefaultTokenProviders();

                // 4) ���� � ��� ���� ��������� ��������� YandexKassa, TypeOfAccessImages � ��
                //    ������� ����� ��� �� "YandexCloud" -> YandexCloudSettings:
                builder.Services.Configure<YandexKassaSettings>(builder.Configuration.GetSection("YandexKassa"));

                
                builder.Services.Configure<TypeOfAccessImages>(options =>
                {
                    // �������� ����� ������
                    var section = builder.Configuration.GetSection("TypeOfAccessImages");
                    // ���� ������ �� ���������� ��� ����� � ����� ����������
                    if (!section.Exists())
                    {
                        // ������ �������� �� ���������
                        options.UseLocalFiles = false;
                        options.LocalPathOfImages = "default_path";
                        return;
                    }

                    try
                    {
                        section.Bind(options);
                    }
                    catch (Exception ex)
                    {
                        // ��������, ������ default
                        Console.WriteLine("������ ��� ������������ TypeOfAccessImages: " + ex.Message);
                        options.UseLocalFiles = false;
                        options.LocalPathOfImages = "default_path";
                    }
                });



                builder.Services.Configure<YandexCloudSettings>(builder.Configuration.GetSection("YandexCloud"));
                //                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                // ��� �� �����������, ��� ��� ��������� � IOptions<YandexCloudSettings> ����� �������� �� appsettings.json

                // 5) JWT
                var jwtKey = builder.Configuration["Jwt:Key"];
                if (!string.IsNullOrWhiteSpace(jwtKey))
                {
                    builder.Services.AddAuthentication(options =>
                    {
                        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
                    })
                    .AddJwtBearer(options =>
                    {
                        options.RequireHttpsMetadata = false;
                        options.SaveToken = true;
                        options.TokenValidationParameters = new TokenValidationParameters
                        {
                            ValidateIssuer = true,
                            ValidateAudience = true,
                            ValidateLifetime = true,
                            ValidateIssuerSigningKey = true,
                            ValidIssuer = builder.Configuration["Jwt:Issuer"],
                            ValidAudience = builder.Configuration["Jwt:Audience"],
                            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
                            RoleClaimType = "roles",
                            NameClaimType = ClaimTypes.NameIdentifier
                        };
                        options.Events = new JwtBearerEvents
                        {
                            OnAuthenticationFailed = context =>
                            {
                                Console.WriteLine("Authentication failed: " + context.Exception.Message);
                                return Task.CompletedTask;
                            },
                            OnTokenValidated = context =>
                            {
                                Console.WriteLine("Token validated: " + context.SecurityToken.Id);
                                return Task.CompletedTask;
                            }
                        };
                    });
                }

                // 6) Authorization 
                builder.Services.AddAuthorization(options =>
                {
                    options.AddPolicy("RequireAdministratorRole", policy => policy.RequireRole("Admin"));
                });

                // 7) ������ scoped-�������
                builder.Services.AddScoped<IRegularBaseBooksRepository, RegularBaseBooksRepository>();
                builder.Services.AddScoped<IUserService, UserService>();
                builder.Services.AddScoped<ISearchHistoryService, SearchHistoryService>();
                builder.Services.AddScoped<IImportService, ImportService>();
                builder.Services.AddScoped<IExportService, ExportService>();
                builder.Services.AddScoped<IBookImagesService, BookImagesService>();
                builder.Services.AddScoped<MigrationService>();

                // 8) ������������ YandexStorageService ������ ������ ����� AddScoped<IYandexStorageService, YandexStorageService>()
                //    � � ����� YandexStorageService ���������� IOptions<YandexCloudSettings>
                builder.Services.AddScoped<IYandexStorageService, YandexStorageService>();

                // 9) IdentityOptions
                builder.Services.Configure<IdentityOptions>(options =>
                {
                    options.Password.RequireDigit = false;
                    options.Password.RequireLowercase = false;
                    options.Password.RequireNonAlphanumeric = false;
                    options.Password.RequireUppercase = false;
                    options.Password.RequiredLength = 6;
                    options.Password.RequiredUniqueChars = 1;
                });

                // 10) Parser services
                builder.Services.AddScoped<ILotDataWebService, LotDataWebService>();
                builder.Services.AddScoped<ILotDataHandler, LotDataHandler>();
                builder.Services.AddScoped<ILotFetchingService, LotFetchingService>();
                builder.Services.AddScoped<IAuctionService, AuctionService>();
                builder.Services.AddScoped<IEmailSenderService, SmtpEmailSenderService>();

                // 11) ������ singletons
                builder.Services.AddSingleton<ICaptchaService, CaptchaService>();
                builder.Services.AddSingleton<ISetupStateService, SetupStateService>();

                // 12) BookUpdateService � singleton + HostedService
                builder.Services.AddSingleton<IBookUpdateService, BookUpdateService>();
                builder.Services.AddHostedService(sp => (BookUpdateService)sp.GetRequiredService<IBookUpdateService>());


                // 13) MemoryCache, AutoMapper, ...
                builder.Services.AddMemoryCache();
                builder.Services.AddAutoMapper(typeof(AutoMapperProfile));

                // 14) Optionally: ��� ��� � �� �����, �. �. ��� ����
                // builder.Services.AddHostedService<BookUpdateService>();

                // Swagger
                builder.Services.AddSwaggerGen(c =>
                {
                    c.SwaggerDoc("v1", new OpenApiInfo { Title = "RareBooksService.WebApi", Version = "v1" });
                    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
                    {
                        In = ParameterLocation.Header,
                        Description = "Please insert JWT with Bearer into field",
                        Name = "Authorization",
                        Type = SecuritySchemeType.ApiKey,
                        Scheme = "Bearer"
                    });
                    c.AddSecurityRequirement(new OpenApiSecurityRequirement {
                    {
                        new OpenApiSecurityScheme {
                            Reference = new OpenApiReference {
                                Type = ReferenceType.SecurityScheme,
                                Id = "Bearer"
                            }
                        },
                        new string[] {}
                    }});
                });

                builder.Services.AddCors(options =>
                {
                    options.AddPolicy("AllowAll", policy =>
                    {
                        policy.AllowAnyOrigin()
                              .AllowAnyMethod()
                              .AllowAnyHeader()
                              .WithExposedHeaders("X-Captcha-Token");
                    });
                });

                // ������ ����������
                var app = builder.Build();

                // ����� ����� �������������� ���� ������ ������ ��������
                using (var scope = app.Services.CreateScope())
                {
                    var dbContext = scope.ServiceProvider.GetRequiredService<RegularBaseBooksContext>();
                    dbContext.Database.Migrate();
                }

                // ���������, ����� �� ���������� InitialSetup
                var setupService = app.Services.GetRequiredService<ISetupStateService>();
                setupService.DetermineIfSetupNeeded();

                // Middleware: ���� IsInitialSetupNeeded == true � ����� InitialSetup
                app.Use(async (context, next) =>
                
                {
                    // ��������� /api/setup/ � /api/setupcheck/
                    if (context.Request.Path.StartsWithSegments("/api/setup") ||
                        context.Request.Path.StartsWithSegments("/api/setupcheck"))
                    {
                        await next.Invoke();
                        return;
                    }

                    // ���� IsInitialSetupNeeded
                    if (setupService.IsInitialSetupNeeded)
                    {
                        if (context.Request.Path.StartsWithSegments("/api"))
                        {
                            context.Response.StatusCode = 403;
                            await context.Response.WriteAsync("System not configured. Please do initial setup via /api/setup or special HTML page.");
                            return;
                        }
                        var filePath = Path.Combine(app.Environment.ContentRootPath, "InitialSetup", "index.html");
                        if (System.IO.File.Exists(filePath))
                        {
                            context.Response.ContentType = "text/html; charset=utf-8";
                            await context.Response.SendFileAsync(filePath);
                        }
                        else
                        {
                            context.Response.StatusCode = 404;
                            await context.Response.WriteAsync("InitialSetup page not found. Please contact admin.");
                        }
                        return;
                    }

                    // ����� � �� ��
                    await next.Invoke();
                });

                // Optional: �������� + seed
                using (var scope = app.Services.CreateScope())
                {
                    // var dbContext = scope.ServiceProvider.GetRequiredService<RegularBaseBooksContext>();
                    // dbContext.Database.Migrate();
                    // ...
                }

                // Swagger
                app.UseSwagger();
                app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "RareBooksService.WebApi v1"));

                // � �. �.
                app.UseHttpsRedirection();
                app.UseRouting();
                app.UseCors("AllowAll");
                app.UseAuthentication();
                app.UseAuthorization();

                app.MapControllers();

                app.Run();
            }
            catch (Exception ex)
            {
                logger.Error(ex, "Stopped program because of an exception");
                throw;
            }
            finally
            {
                NLog.LogManager.Shutdown();
            }
        }
    }
}
