# --------------------------------------------------
# 1) ���� build: ���������� .NET 6 SDK, �������� �������
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src

# �������� .csproj-����� ��� ���� .NET-��������, ������� ������ ����������� � ������.
# � ������: RareBooksService.WebApi, RareBooksService.Common, RareBooksService.Data, RareBooksService.Parser
# (�� �������� sln, �� �������� .esproj-����� ��������� � �.�.)
COPY ["RareBooksService.WebApi/RareBooksService.WebApi.csproj", "RareBooksService.WebApi/"]
COPY ["RareBooksService.Common/RareBooksService.Common.csproj", "RareBooksService.Common/"]
COPY ["RareBooksService.Data/RareBooksService.Data.csproj",     "RareBooksService.Data/"]
COPY ["RareBooksService.Parser/RareBooksService.Parser.csproj", "RareBooksService.Parser/"]

# 1a) ��������� restore ��� ������� ������� .csproj �� �����������, 
# ����, ��� �������, ��� WebApi (������� �������� ����������� �� Common/Data/Parser).
# 
# ������� A: (�����, �. �. �����������, ��� ��� .csproj-����������� ������������.)
# RUN dotnet restore "RareBooksService.Common/RareBooksService.Common.csproj"
# RUN dotnet restore "RareBooksService.Data/RareBooksService.Data.csproj"
# RUN dotnet restore "RareBooksService.Parser/RareBooksService.Parser.csproj"
# RUN dotnet restore "RareBooksService.WebApi/RareBooksService.WebApi.csproj"

# ������� B: (����� ������� ������ restore �� ������, � ������� ProjectReference �� Common/Data/Parser.)
RUN dotnet restore "RareBooksService.WebApi/RareBooksService.WebApi.csproj"

# 2) �������� ���� ���������� �������� ��� (��� ����� RareBooksService.WebApi, .Common, .Data, .Parser)
COPY . .

# ��������� � ����� WebApi
WORKDIR /src/RareBooksService.WebApi

# 3) ��������� � ����� /app/out (Release)
RUN dotnet publish -c Release -o /app/out

# --------------------------------------------------
# 2) ���� runtime: .NET 6 ASP.NET
# --------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app

# 4) �������� ��������� �� ����������� �����
COPY --from=build /app/out ./

# ��������� ���� 80 ������ ����������
EXPOSE 80

# 5) ������
ENTRYPOINT ["dotnet", "RareBooksService.WebApi.dll"]
