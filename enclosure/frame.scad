// ====================================================================
// DIY E-Ink Photo Frame (PicPak Style)
// Parametric Enclosure for Waveshare 4.2" e-Paper Module + FireBeetle 2
// ====================================================================
// Render modes:
//   part = "all";   // Assembly view
//   part = "front"; // Front bezel for 3D printing
//   part = "back";  // Back cover for 3D printing
// ====================================================================

part = "all"; // ["all", "front", "back"]

$fn = 40;

// Dimensions (mm)
// Display active area: 84.8 x 63.6 mm
// Display module PCB: ~103.0 x 78.5 x 1.2 mm
screen_window_w = 86.0;   // Visible display opening
screen_window_h = 65.0;

screen_pocket_w = 104.0;  // Recess to seat the module
screen_pocket_h = 80.0;
screen_pocket_d = 2.5;

// Overall Enclosure Dimensions (Polaroid format)
frame_w = 114.0;
frame_h = 106.0;
frame_corner_r = 6.0;

front_thickness = 4.0;
back_thickness = 8.5;
wall = 2.0;

// Internal electronics pocket
cavity_w = 104.0;
cavity_h = 96.0;
cavity_depth = 6.5; // Accommodates FireBeetle 2 + LiPo battery pouch

// Magnet recesses (10mm diameter x 2mm depth)
mag_d = 10.2;
mag_depth = 2.1;

// USB-C port cutout
usbc_w = 11.0;
usbc_h = 6.5;

// Tactile button cutout
btn_hole_d = 4.0;

// Helper: Rounded Rectangle
module rounded_rect(w, h, d, r) {
    hull() {
        translate([r, r, 0]) cylinder(r=r, h=d);
        translate([w-r, r, 0]) cylinder(r=r, h=d);
        translate([r, h-r, 0]) cylinder(r=r, h=d);
        translate([w-r, h-r, 0]) cylinder(r=r, h=d);
    }
}

// --------------------------------------------------------------------
// FRONT FRAME
// --------------------------------------------------------------------
module front_frame() {
    difference() {
        // Outer Body
        rounded_rect(frame_w, frame_h, front_thickness, frame_corner_r);

        // Screen Window Cutout (Beveled slightly for clean look)
        translate([(frame_w - screen_window_w)/2, frame_h - screen_window_h - 12.0, -0.1])
            cube([screen_window_w, screen_window_h, front_thickness + 0.2]);

        // Screen Module Seating Pocket on the back side of front frame
        translate([(frame_w - screen_pocket_w)/2, frame_h - screen_pocket_h - 6.0, front_thickness - screen_pocket_d])
            cube([screen_pocket_w, screen_pocket_h, screen_pocket_d + 0.1]);

        // Snap-fit rim / screw hole recesses (Corner alignment tabs)
        translate([6, 6, front_thickness - 2]) cylinder(r=1.5, h=2.1);
        translate([frame_w - 6, 6, front_thickness - 2]) cylinder(r=1.5, h=2.1);
        translate([6, frame_h - 6, front_thickness - 2]) cylinder(r=1.5, h=2.1);
        translate([frame_w - 6, frame_h - 6, front_thickness - 2]) cylinder(r=1.5, h=2.1);
    }
}

// --------------------------------------------------------------------
// BACK COVER
// --------------------------------------------------------------------
module back_cover() {
    difference() {
        // Outer Shell
        rounded_rect(frame_w, frame_h, back_thickness, frame_corner_r);

        // Internal Cavity for FireBeetle 2 + LiPo Pouch
        translate([(frame_w - cavity_w)/2, (frame_h - cavity_h)/2, -0.1])
            rounded_rect(cavity_w, cavity_h, cavity_depth + 0.1, 3.0);

        // 4x Neodymium Magnet Pockets on rear surface
        translate([15, 15, back_thickness - mag_depth]) cylinder(d=mag_d, h=mag_depth + 0.2);
        translate([frame_w - 15, 15, back_thickness - mag_depth]) cylinder(d=mag_d, h=mag_depth + 0.2);
        translate([15, frame_h - 15, back_thickness - mag_depth]) cylinder(d=mag_d, h=mag_depth + 0.2);
        translate([frame_w - 15, frame_h - 15, back_thickness - mag_depth]) cylinder(d=mag_d, h=mag_depth + 0.2);

        // USB-C Charging Port on Bottom Edge
        translate([(frame_w - usbc_w)/2, -1, 1.5])
            cube([usbc_w, wall + 2, usbc_h]);

        // Upload Button Hole on Right Edge
        translate([frame_w - wall - 1, 30, 2.5])
            rotate([0, 90, 0])
                cylinder(d=btn_hole_d, h=wall + 2);
    }

    // Corner Alignment / Snap Pins
    translate([6, 6, cavity_depth]) cylinder(r=1.4, h=1.8);
    translate([frame_w - 6, 6, cavity_depth]) cylinder(r=1.4, h=1.8);
    translate([6, frame_h - 6, cavity_depth]) cylinder(r=1.4, h=1.8);
    translate([frame_w - 6, frame_h - 6, cavity_depth]) cylinder(r=1.4, h=1.8);
}

// --------------------------------------------------------------------
// SCENE RENDER
// --------------------------------------------------------------------
if (part == "all") {
    color("GhostWhite") front_frame();
    translate([0, 0, front_thickness + 12])
        color("#222222") back_cover();
} else if (part == "front") {
    front_frame();
} else if (part == "back") {
    back_cover();
}
