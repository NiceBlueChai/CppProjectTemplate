from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, cmake_layout

class CompressorRecipe(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"

    def requirements(self):
        self.requires("nlohmann_json/3.11.3")
        self.requires("fmt/10.2.1")
        self.requires("spdlog/1.13.0")
        self.requires("catch2/3.8.0")
        self.requires("cxxopts/3.1.1")


    def layout(self):
        cmake_layout(self)
