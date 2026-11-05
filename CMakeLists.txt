cmake_minimum_required(VERSION 3.16)

project(SmartSlate VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick VirtualKeyboard)

qt_standard_project_setup(REQUIRES 6.10)

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appSmartSlate
    main.cpp
    brightnesscontroller.cpp
    brightnesscontroller.h
    batterymonitor.cpp
    batterymonitor.h
    batteryestimator.cpp
    batteryestimator.h
    max17048.cpp
    max17048.h
)

qt_add_qml_module(appSmartSlate
    URI SmartSlate
    QML_FILES
        Main.qml
        SlateField.qml
        SlateNotesField.qml
        VerticalFieldLabel.qml
        GearIcon.qml
        SceneTakeKeyboard.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appSmartSlate PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appSmartSlate
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appSmartSlate
    PRIVATE Qt6::Quick Qt6::VirtualKeyboard
)

install(TARGETS appSmartSlate
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(tst_battery
        tests/tst_battery.cpp
        batterymonitor.cpp
        batterymonitor.h
        batteryestimator.cpp
        max17048.cpp
    )
    target_include_directories(tst_battery PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
    set_target_properties(tst_battery PROPERTIES WIN32_EXECUTABLE FALSE)
    target_link_libraries(tst_battery PRIVATE Qt6::Core Qt6::Test)
    add_test(NAME battery COMMAND tst_battery -o -,txt)
endif()
