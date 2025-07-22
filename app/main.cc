#include <filesystem>
#include <fstream>
#include <iostream>

#include <cxxopts.hpp>
#include <fmt/format.h>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

#include "config.hpp"
#include "foo.h"
#include "version_generated.h"  // Include the generated version header

using json = nlohmann::json;
namespace fs = std::filesystem;

int main(int argc, char **argv)
{
    // Display version information
    fmt::print("=== Project Version Information ===\n");
    fmt::print("Project Version: {}\n", Version::getFullVersionString());
    fmt::print("Version Number: {}.{}.{}\n", VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH);
    fmt::print("Git Commit: {}\n", GIT_COMMIT_HASH);
    fmt::print("Git Branch: {}\n", GIT_BRANCH);
    fmt::print("Build Time: {}\n", BUILD_TIMESTAMP);
    fmt::print("Build Type: {}\n", BUILD_TYPE);
    fmt::print("Current Build Config: {}\n", Version::getBuildConfiguration());
    fmt::print("Detailed Build Config: {}\n", Version::getDetailedBuildConfiguration());
    fmt::print("Compiler: {} {}\n", COMPILER_ID, COMPILER_VERSION);
    fmt::print("Current Build Flags: {}\n", Version::getCurrentBuildFlags());
    fmt::print("\n");

    // Demonstrate version comparison macros
    std::cout << "=== Version Comparison Examples ===\n";
    
#if PROJECT_VERSION >= PROJECT_VERSION_CHECK(1, 0, 0)
    std::cout << "✓ This is version 1.0.0 or higher\n";
#else
    std::cout << "✗ This is a version below 1.0.0\n";
#endif

#if PROJECT_VERSION_AT_LEAST(1, 0, 0)
    std::cout << "✓ Using PROJECT_VERSION_AT_LEAST macro: version >= 1.0.0\n";
#endif

#if PROJECT_VERSION_MAJOR_AT_LEAST(1)
    std::cout << "✓ Major version is at least 1\n";
#endif

    // Conditional compilation example
#if PROJECT_VERSION >= PROJECT_VERSION_CHECK(2, 0, 0)
    std::cout << "This code would only compile for version 2.0.0+\n";
#elif PROJECT_VERSION >= PROJECT_VERSION_CHECK(1, 5, 0)
    std::cout << "This code would compile for version 1.5.0-1.x.x\n";
#else
    std::cout << "This code compiles for version below 1.5.0\n";
#endif

    std::cout << "\n=== Library Versions ===\n";
    std::cout << "JSON: " << NLOHMANN_JSON_VERSION_MAJOR << "."
              << NLOHMANN_JSON_VERSION_MINOR << "."
              << NLOHMANN_JSON_VERSION_PATCH << '\n';
    std::cout << "FMT: " << FMT_VERSION << '\n';
    std::cout << "CXXOPTS: " << CXXOPTS__VERSION_MAJOR << "."
              << CXXOPTS__VERSION_MINOR << "." << CXXOPTS__VERSION_PATCH
              << '\n';
    std::cout << "SPDLOG: " << SPDLOG_VER_MAJOR << "." << SPDLOG_VER_MINOR
              << "." << SPDLOG_VER_PATCH << '\n';
    std::cout << "\n\nUsage Example:\n";

    // Compiler Warning and clang tidy error
    // std::int32_t i = 0;

    // Adress Sanitizer should see this
    // char x[10];
    // x[11] = 1;

    const auto welcome_message =
        fmt::format("Welcome to {} v{}\n", project_name, project_version);
    spdlog::info(welcome_message);

    cxxopts::Options options(project_name.data(), welcome_message);

    options.add_options("arguments")("h,help", "Print usage")(
        "f,filename",
        "File name",
        cxxopts::value<std::string>())(
        "v,verbose",
        "Verbose output",
        cxxopts::value<bool>()->default_value("false"));

    auto result = options.parse(argc, argv);

    if (argc == 1 || result.count("help"))
    {
        std::cout << options.help() << '\n';
        return 0;
    }

    auto filename = std::string{};
    auto verbose = false;

    if (result.count("filename"))
    {
        filename = result["filename"].as<std::string>();
    }
    else
    {
        return 1;
    }

    verbose = result["verbose"].as<bool>();

    if (verbose)
    {
        fmt::print("Opening file: {}\n", filename);
    }

    auto ifs = std::ifstream{filename};

    if (!ifs.is_open())
    {
        return 1;
    }

    const auto parsed_data = json::parse(ifs);

    if (verbose)
    {
        const auto name = parsed_data["name"];
        fmt::print("Name: {}\n", name.dump());
    }

    return 0;
}
