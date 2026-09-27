// ====================================================================
// DIY E-Ink Photo Frame (PicPak Style) - Full Feature Edition
// Parametric Enclosure with Flush Kickstand + 4x Fridge Magnets
// ====================================================================
// Render modes:
//   part = "all";       // Exploded assembly view
//   part = "front";     // Front bezel for 3D printing
//   part = "back";      // Back cover with magnet pockets & kickstand slot
//   part = "kickstand"; // Fold-out kickstand arm
// ====================================================================

part = "all"; // ["all", "front", "back", "kickstand"]

$fn = 40;

// Dimensions (mm)
// Display active area: 84.8 x 63.6 mm
screen_window_w = 86.0;   // Visible display opening
screen_window_h = 65.0;

screen_pocket_w = 104.0;  // Recess to seat the module PCB
screen_pocket_h = 80.0;
screen_pocket_d = 2.5;

// Overall Enclosure Dimensions (Polaroid format)
frame_w = 114.0;
frame_h = 106.0;
frame_corner_r = 6.0;

front_thickness = 4.0;
back_thickness = 9.0;
wall = 2.0;

// Internal electronics pocket (FireBeetle 2 + LiPo battery)
cavity_w = 104.0;
cavity_h = 96.0;
cavity_depth = 6.8;

// Magnet recesses (10mm diameter x 2mm depth)
mag_d = 10.2;
mag_depth = 2.1;

// USB-C port cutout
usbc_w = 11.0;
usbc_h = 6.5;

// Tactile button cutout
btn_hole_d = 4.0;

// Kickstand Dimensions (stows completely flush with rear face)
ks_w = 22.0;
ks_len = 68.0;
ks_thick = 2.2;
pin_r = 1.4;

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

        // Screen Window Cutout
        translate([(frame_w - screen_window_w)/2, frame_h - screen_window_h - 12.0, -0.1])
            cube([screen_window_w, screen_window_h, front_thickness + 0.2]);

        // Screen Module Seating Pocket on the back side of front frame
        translate([(frame_w - screen_pocket_w)/2, frame_h - screen_pocket_h - 6.0, front_thickness - screen_pocket_d])
            cube([screen_pocket_w, screen_pocket_h, screen_pocket_d + 0.1]);

        // Corner snap alignment pin holes
        translate([6, 6, front_thickness - 2]) cylinder(r=1.5, h=2.1);
        translate([frame_w - 6, 6, front_thickness - 2]) cylinder(r=1.5, h=2.1);
        translate([6, frame_h - 6, front_thickness - 2]) cylinder(r=1.5, h=2.1);
        translate([frame_w - 6, frame_h - 6, front_thickness - 2]) cylinder(r=1.5, h=2.1);
    }
}

// --------------------------------------------------------------------
// KICKSTAND
// --------------------------------------------------------------------
module kickstand() {
    difference() {
        union() {
            // Main leg
            hull() {
                translate([ks_w/2, ks_w/2, 0]) cylinder(d=ks_w, h=ks_thick);
                translate([ks_w/2, ks_len - 6, 0]) cylinder(d=12, h=ks_thick);
            }
            // Pivot pins on top corners
            translate([-1.8, ks_w/2, ks_thick/2])
                rotate([0, 90, 0]) cylinder(r=pin_r, h=ks_w + 3.6);
        }
        // Finger grip notch for easy pull-out
        translate([ks_w/2, ks_len - 10, -0.1])
            cylinder(d=8, h=ks_thick + 0.2);
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
        translate([12, 12, back_thickness - mag_depth]) cylinder(d=mag_d, h=mag_depth + 0.2);
        translate([frame_w - 12, 12, back_thickness - mag_depth]) cylinder(d=mag_d, h=mag_depth + 0.2);
        translate([12, frame_h - 12, back_thickness - mag_depth]) cylinder(d=mag_d, h=mag_depth + 0.2);
        translate([frame_w - 12, frame_h - 12, back_thickness - mag_depth]) cylinder(d=mag_d, h=mag_depth + 0.2);

        // Flush Recess for Stowed Kickstand
        translate([(frame_w - ks_w - 1.0)/2, 18, back_thickness - ks_thick - 0.2])
            hull() {
                translate([(ks_w+1)/2, (ks_w+1)/2, 0]) cylinder(d=ks_w+1.2, h=ks_thick + 1.0);
                translate([(ks_w+1)/2, ks_len - 4, 0]) cylinder(d=14, h=ks_thick + 1.0);
            }

        // Hinge Pin Sockets for Kickstand Pivot
        translate([(frame_w - ks_w)/2 - 2.5, 18 + ks_w/2, back_thickness - ks_thick/2 - 0.2])
            rotate([0, 90, 0])
                cylinder(r=pin_r + 0.2, h=ks_w + 5.0);

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
    translate([0, 0, front_thickness + 12]) {
        color("#222222") back_cover();
        // Stowed kickstand preview
        translate([(frame_w - ks_w)/2, 18, back_thickness - ks_thick])
            color("#c9882b") kickstand();
    }
} else if (part == "front") {
    front_frame();
} else if (part == "back") {
    back_cover();
} else if (part == "kickstand") {
    kickstand();
}

