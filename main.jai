my_window: Window_Type;
window_width  : s32 = 1920;
window_height : s32 = 1080;

image_test: Simp.Texture;

Bunny :: struct {
    x_position: float;
    y_position: float;
    x_direction: float;
    y_direction: float;
}
current_time : Apollo_Time;
bunny_count := 10_000;
bunny_arr : [10_000_000]Bunny;
bunny_size := 32;
bunny_move_distance : float = 2;

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    my_window = create_window(window_width, window_height, "A Window", wanted_msaa = WANTED_MSAA);

    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window(my_window, wanted_msaa = WANTED_MSAA);
    log("Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa);

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    window_width, window_height = Simp.get_render_dimensions(my_window);

    Simp.set_render_target(my_window, .LEFT_HANDED);

    my_init_fonts();
    success := Simp.texture_load_from_file(*image_test, "bunny.bmp");
    assert(success);

    quit := false;
    while !quit {
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.

            if it.window == my_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);

                window_width  = it.width;
                window_height = it.height;

                if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    quit = true;
                }

                if it.key_pressed && it.key_code == #char " " {
                    bunny_count += 1_000;
                }
            }
        }

        draw_one_frame();
        reset_temporary_storage();
    }
}



draw_one_frame :: () {

    delta_time := to_float64_seconds(current_time_monotonic() - current_time) * 1000;
    current_time = current_time_monotonic();

    Simp.clear_render_target(.15, .08, .08, 1);

    Simp.set_shader_for_color();

    time := seconds_since_init();
    
    if image_test.width && image_test.height {
        Simp.set_shader_for_images(*image_test);
        Simp.immediate_begin();

        for 0..bunny_count {
            if bunny_arr[it].x_direction == 0 && bunny_arr[it].x_direction == 0 {
                x_pos := random_get_within_range(0, cast(float)window_width - bunny_size);
                y_pos := random_get_within_range(0, cast(float)window_height -  bunny_size);
                theta := random_get_within_range(0, 2 * PI);
                x_dir := cos(theta);
                y_dir := sin(theta);
                bunny_arr[it] = .{x_pos, y_pos, x_dir, y_dir};
            }
            if bunny_arr[it].x_position > cast(float)window_width - bunny_size || bunny_arr[it].x_position < 0 {
                bunny_arr[it].x_direction = -bunny_arr[it].x_direction;
            } else if bunny_arr[it].y_position > cast(float)window_height - bunny_size || bunny_arr[it].y_position < 0 {
                bunny_arr[it].y_direction = -bunny_arr[it].y_direction;
            }

            bunny_arr[it].x_position += bunny_move_distance * bunny_arr[it].x_direction;
            bunny_arr[it].y_position += bunny_move_distance * bunny_arr[it].y_direction;

            Simp.immediate_quad(bunny_arr[it].x_position, bunny_arr[it].y_position, bunny_arr[it].x_position + bunny_size, bunny_arr[it].y_position + bunny_size, .{1, 1, 1, 1});
        }
        Simp.immediate_flush();
    }

    
    // Draw some text.
    {
        // Do a bunch of wacky math to figure out the text color.
        theta := cast(float) fmod_cycling(time*3, TAU);

        color: Vector4;
        color.x = cos(theta)*.5+.5;
        Clamp(*color.x, 0, 1);
        color.y = 1;
        color.z = sin(theta)*-.5+.5;
        Clamp(*color.z, 0, 1);
        color.w = 1;

        // Now, to draw the text:

        text_bunny_count := tprint("Bunny Count: %. (Press space to add more!)", bunny_count);
        text_width_bunny_count := Simp.prepare_text(my_font, text_bunny_count);
        text_x_bunny_count := (window_width - text_width_bunny_count) / 2;
        text_y_bunny_count := window_height/2 + my_font.character_height/4;
        Simp.draw_prepared_text(my_font, text_x_bunny_count, text_y_bunny_count, color);

        delta_time_pruned := tprint("%", delta_time);
        delta_time_pruned.count = 4;
        text_delta_time := tprint("Delta Time: % ms", delta_time_pruned);
        text_x_delta_time := ((window_width) / 2) - 220;
        text_y_delta_time := (window_height/2) + (my_font.character_height * 2);
        Simp.draw_text(my_font, text_x_delta_time, text_y_delta_time, text_delta_time, color);
    }



    Simp.swap_buffers(my_window);
}

my_init_fonts :: () {
    // So that we can load our font, set to path of running executable.
    // @Incomplete: Pack a default font into Simp.

    if !working_directory_set {
        path := path_strip_filename(get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }

    pixel_height := window_height / 24;

    // @Cleanup: Don't have path + name be separate.
    my_font = Simp.get_font_at_size(".", "OpenSans-BoldItalic.ttf", pixel_height);
    assert(my_font != null);
}

working_directory_set := false;

my_font: *Simp.Dynamic_Font;

Simp  :: #import "Simp";
Input :: #import "Input";

#import "Window_Creation";

#import "Basic";
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.
#import "Random";

#run {
    #if OS == .WINDOWS {
        WR :: #import "Windows_Resources";
        WR.disable_runtime_console();
    }
}