using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using NLog.Web;
using RareBooksService.Common.Models;
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

                // Remove default logging providers and add NLog
                builder.Logging.ClearProviders();
                builder.Host.UseNLog();

                // Add services to the container.
                builder.Services.AddControllers();

                builder.Services.AddSingleton<NullToZeroMaterializationInterceptor>();
                builder.Services.AddDbContext<RegularBaseBooksContext>((serviceProvider, options) =>
                {
                    var interceptor = serviceProvider.GetRequiredService<NullToZeroMaterializationInterceptor>();
                    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"));
                    options.AddInterceptors(interceptor);
                });

                builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
                    .AddEntityFrameworkStores<RegularBaseBooksContext>()
                    .AddDefaultTokenProviders();

                builder.Services.Configure<YandexKassaSettings>(builder.Configuration.GetSection("YandexKassa"));
                builder.Services.Configure<TypeOfAccessImages>(builder.Configuration.GetSection("TypeOfAccessImages"));


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
                            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"])),
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

                builder.Services.AddAuthorization(options =>
                {
                    options.AddPolicy("RequireAdministratorRole", policy => policy.RequireRole("Admin"));
                });

                builder.Services.AddScoped<IRegularBaseBooksRepository, RegularBaseBooksRepository>();
                builder.Services.AddScoped<IUserService, UserService>();
                builder.Services.AddScoped<ISearchHistoryService, SearchHistoryService>();
                builder.Services.AddScoped<IYandexStorageService, YandexStorageService>();
                builder.Services.AddScoped<MigrationService>();
                builder.Services.AddScoped<IExportService, ExportService>();
                builder.Services.AddScoped<IImportService, ImportService>();

                builder.Services.Configure<IdentityOptions>(options =>
                {
                    options.Password.RequireDigit = false;
                    options.Password.RequireLowercase = false;
                    options.Password.RequireNonAlphanumeric = false;
                    options.Password.RequireUppercase = false;
                    options.Password.RequiredLength = 6;
                    options.Password.RequiredUniqueChars = 1;
                });


                // Register parser services
                builder.Services.AddScoped<ILotDataWebService, LotDataWebService>();
                builder.Services.AddScoped<ILotDataHandler, LotDataHandler>();
                builder.Services.AddScoped<ILotFetchingService, LotFetchingService>();
                builder.Services.AddScoped<IAuctionService, AuctionService>();

                // Register Yandex Storage Service
                builder.Services.AddScoped<IYandexStorageService, YandexStorageService>();

                // В ConfigureServices:
                builder.Services.AddSingleton<ICaptchaService, CaptchaService>();
                builder.Services.AddSingleton<ISetupStateService, SetupStateService>();
                builder.Services.AddMemoryCache();


                // Register AutoMapper
                builder.Services.AddAutoMapper(typeof(AutoMapperProfile));

                // Register Background Service
                builder.Services.AddHostedService<BookUpdateService>();

                // Swagger configuration
                builder.Services.AddSwaggerGen(c =>
                {
                    c.SwaggerDoc("v1", new OpenApiInfo { Title = "RareBooksService.WebApi", Version = "v1" });

                    // Configure Swagger to use JWT authentication
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
                    }
                    });
                });

                // Configure CORS
                /*builder.Services.AddCors(options =>
                {
                    options.AddPolicy("AllowAllOrigins",
                        builder => builder.AllowAnyOrigin()
                                          .AllowAnyMethod()
                                          .AllowAnyHeader());
                });*/
                builder.Services.AddCors(options =>
                {
                    options.AddPolicy("AllowAll", builder =>
                    {
                        builder.AllowAnyOrigin()
                               .AllowAnyMethod()
                               .AllowAnyHeader()
                               .WithExposedHeaders("X-Captcha-Token"); // expose custom header
                    });
                });

                var app = builder.Build();


                var setupService = app.Services.GetRequiredService<ISetupStateService>();
                setupService.DetermineIfSetupNeeded();

                app.Use(async (context, next) =>
                {
                    // 1. Разрешаем запросы к /api/setup/ и /api/setupcheck/, 
                    //    чтобы SetupController и SetupCheckController продолжали работать
                    if (context.Request.Path.StartsWithSegments("/api/setup") ||
                        context.Request.Path.StartsWithSegments("/api/setupcheck"))
                    {
                        await next.Invoke();
                        return;
                    }

                    // 2. Если IsInitialSetupNeeded, то показываем HTML со страницей настройки
                    if (setupService.IsInitialSetupNeeded)
                    {
                        // (а) Если пришел запрос на /api/*, но не /api/setup, даем 403
                        if (context.Request.Path.StartsWithSegments("/api"))
                        {
                            context.Response.StatusCode = 403;
                            await context.Response.WriteAsync("System not configured. Please do initial setup via /api/setup or special HTML page.");
                            return;
                        }

                        // (б) Иначе отдаем статику из папки InitialSetup (index.html)
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

                    // Если система настроена, идем дальше
                    await next.Invoke();
                });



                var lifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
                // Apply migrations at startup and seed admin user
                using (var scope = app.Services.CreateScope())
                {
                    /*var dbContext = scope.ServiceProvider.GetRequiredService<RegularBaseBooksContext>();
                    dbContext.Database.Migrate();

                    var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
                    var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
                    var configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();
                    DataInitializer.SeedData(userManager, roleManager, configuration).Wait();

                    // Check if there are no books in the database and perform migration if necessary
                    var booksExist = dbContext.BooksInfo.Any();
                    if (!booksExist)
                    {
                        var migrationService = scope.ServiceProvider.GetRequiredService<MigrationService>();
                        migrationService.MigrateDataAsync().Wait();
                    }*/

                    var exportService = scope.ServiceProvider.GetRequiredService<IExportService>();

                    lifetime.ApplicationStopping.Register(() =>
                    {
                        exportService.CleanupAllFiles();
                    });
                }

                // Configure the HTTP request pipeline.
                //if (app.Environment.IsDevelopment())
                //{
                app.UseSwagger();
                app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "RareBooksService.WebApi v1"));
                //}

                app.UseHttpsRedirection();

                app.UseRouting();

                //app.UseCors("AllowAllOrigins");
                app.UseCors("AllowAll");

                app.UseAuthentication();
                app.UseAuthorization();

                app.MapControllers();                

                app.Run();
            }
            catch (Exception ex)
            {
                // NLog: catch setup errors
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
