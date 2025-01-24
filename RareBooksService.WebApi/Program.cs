using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using NLog.Web;
using RareBooksService.Common.Models;            // <-- Для YandexCloudSettings
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

                // Убираем дефолтных провайдеров логов и подключаем NLog
                builder.Logging.ClearProviders();
                builder.Host.UseNLog();

                // 1) Добавляем контроллеры
                builder.Services.AddControllers();

                // 2) Настройка DbContext
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

                // 4) Если у вас есть отдельные настройки YandexKassa, TypeOfAccessImages – ок
                //    Добавим РОВНО так же "YandexCloud" -> YandexCloudSettings:
                builder.Services.Configure<YandexKassaSettings>(builder.Configuration.GetSection("YandexKassa"));

                
                builder.Services.Configure<TypeOfAccessImages>(options =>
                {
                    // Пытаемся взять секцию
                    var section = builder.Configuration.GetSection("TypeOfAccessImages");
                    // Если секция не существует или пуста — можно пропустить
                    if (!section.Exists())
                    {
                        // задать значения по умолчанию
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
                        // логируем, ставим default
                        Console.WriteLine("Ошибка при конфигурации TypeOfAccessImages: " + ex.Message);
                        options.UseLocalFiles = false;
                        options.LocalPathOfImages = "default_path";
                    }
                });



                builder.Services.Configure<YandexCloudSettings>(builder.Configuration.GetSection("YandexCloud"));
                //                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                // Так мы гарантируем, что при обращении к IOptions<YandexCloudSettings> будут значения из appsettings.json

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

                // 7) Разные scoped-сервисы
                builder.Services.AddScoped<IRegularBaseBooksRepository, RegularBaseBooksRepository>();
                builder.Services.AddScoped<IUserService, UserService>();
                builder.Services.AddScoped<ISearchHistoryService, SearchHistoryService>();
                builder.Services.AddScoped<IImportService, ImportService>();
                builder.Services.AddScoped<IExportService, ExportService>();
                builder.Services.AddScoped<IBookImagesService, BookImagesService>();
                builder.Services.AddScoped<MigrationService>();

                // 8) Регистрируем YandexStorageService теперь ТОЛЬКО через AddScoped<IYandexStorageService, YandexStorageService>()
                //    и в самом YandexStorageService используем IOptions<YandexCloudSettings>
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

                // 11) Прочие singletons
                builder.Services.AddSingleton<ICaptchaService, CaptchaService>();
                builder.Services.AddSingleton<ISetupStateService, SetupStateService>();

                // 12) BookUpdateService – singleton + HostedService
                builder.Services.AddSingleton<IBookUpdateService, BookUpdateService>();
                builder.Services.AddHostedService(sp => (BookUpdateService)sp.GetRequiredService<IBookUpdateService>());


                // 13) MemoryCache, AutoMapper, ...
                builder.Services.AddMemoryCache();
                builder.Services.AddAutoMapper(typeof(AutoMapperProfile));

                // 14) Optionally: ещё раз – не нужно, т. к. уже выше
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

                // Строим приложение
                var app = builder.Build();

                // Перед любым использованием базы данных делаем миграцию
                using (var scope = app.Services.CreateScope())
                {
                    var dbContext = scope.ServiceProvider.GetRequiredService<RegularBaseBooksContext>();
                    dbContext.Database.Migrate();
                }

                // Проверяем, нужно ли показывать InitialSetup
                var setupService = app.Services.GetRequiredService<ISetupStateService>();
                setupService.DetermineIfSetupNeeded();

                // Middleware: если IsInitialSetupNeeded == true – отдаём InitialSetup
                app.Use(async (context, next) =>
                
                {
                    // Разрешаем /api/setup/ и /api/setupcheck/
                    if (context.Request.Path.StartsWithSegments("/api/setup") ||
                        context.Request.Path.StartsWithSegments("/api/setupcheck"))
                    {
                        await next.Invoke();
                        return;
                    }

                    // Если IsInitialSetupNeeded
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

                    // Иначе – всё ок
                    await next.Invoke();
                });

                // Optional: миграции + seed
                using (var scope = app.Services.CreateScope())
                {
                    // var dbContext = scope.ServiceProvider.GetRequiredService<RegularBaseBooksContext>();
                    // dbContext.Database.Migrate();
                    // ...
                }

                // Swagger
                app.UseSwagger();
                app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "RareBooksService.WebApi v1"));

                // и т. д.
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
