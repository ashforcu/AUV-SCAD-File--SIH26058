// =====================================================================
//  AUV SONAR PAYLOAD  -  MODEL 1 : CLOSED HULL (external view)
//  Envelope: length 450 mm | diameter 100 mm | nose 100 | central 250 | tail 100
//  Axis along +X: x = 0 at the nose tip, x = 450 at the propeller hub end.
//  F5 = quick preview, F6 = full render (then Export STL/3MF).
// =====================================================================

// ---------------- CONTROLS ----------------
cutaway_mode    = 0;   // 0 = closed hull, 1 = longitudinal half cut
explode         = 0;   // exploded view spacing (mm per step). 0 = assembled, try 25
show_dimensions = 0;   // 1 = draw basic dimension labels

// default camera (3/4 view of the nose, fins and propeller)
$vpr = [65, 0, 20];
$vpt = [225, 0, 0];
$vpd = 850;

// =====================================================================
//  MODEL BODY  (identical in both files - only the controls above differ)
// =====================================================================

// ---------- Nominal envelope (mm) ----------
L        = 450;                 // overall length
D        = 100;                 // hull diameter
R        = D/2;
nose_len = 100;
mid_len  = 250;
tail_len = 100;
wall     = 4;                   // hull wall thickness
x_j1     = nose_len;            // nose / central joint  (x = 100)
x_j2     = nose_len + mid_len;  // central / tail joint  (x = 350)

// ---------- Derived details ----------
win_len          = 30;          // acoustic window length from nose tip
tail_taper_start = x_j2 + 15;   // tail cone starts tapering (x = 365)
tail_end         = 436;         // aft face of tail cap (propeller sits behind it, ends at x = 450)
tail_end_r       = 21;          // tail cap radius

// ---------- Colours ----------
c_hull   = [0.96, 0.72, 0.08];
c_window = [0.10, 0.14, 0.18, 0.70];
c_metal  = [0.72, 0.74, 0.78];
c_steel  = [0.55, 0.57, 0.60];
c_dark   = [0.14, 0.14, 0.16];
c_pcb    = [0.05, 0.45, 0.25];
c_chip   = [0.07, 0.07, 0.08];
c_batt   = [0.12, 0.42, 0.75];
c_brass  = [0.85, 0.65, 0.20];
c_copper = [0.80, 0.45, 0.25];
c_oring  = [0.02, 0.02, 0.02];
c_fin    = [0.12, 0.12, 0.14];
c_prop   = [0.72, 0.55, 0.25];
c_red    = [0.85, 0.10, 0.10];
c_blue   = [0.15, 0.35, 0.90];
c_orange = [0.95, 0.45, 0.05];

// =====================================================================
//  HELPERS  (all parts are built along the +X axis)
// =====================================================================
module cyl_x(x0, len, d, fn = 64)
    translate([x0, 0, 0]) rotate([0, 90, 0]) cylinder(h = len, d = d, $fn = fn);

module tube_x(x0, len, od, id, fn = 64)
    difference() {
        cyl_x(x0, len, od, fn);
        cyl_x(x0 - 0.1, len + 0.2, id, fn);
    }

// revolve a [radius, x] profile around the X axis
module revolve_x(pts, fn = 96)
    rotate([0, 90, 0]) rotate_extrude($fn = fn) polygon(pts);

module oring(x, r, cord = 3)
    translate([x, 0, 0]) rotate([0, 90, 0])
        rotate_extrude($fn = 64) translate([r, 0]) circle(d = cord, $fn = 16);

// cable = chain of hulled spheres through a list of 3D points
module cable(p, d = 3.5)
    for (i = [0 : len(p) - 2])
        hull() {
            translate(p[i])     sphere(d = d, $fn = 12);
            translate(p[i + 1]) sphere(d = d, $fn = 12);
        }

// Half-space clip: keeps y >= y0 when cutaway_mode == 1 (cut face on the XZ plane).
// y0 is a hair-thin (<0.06 mm) offset derived from the part colour, so parts of
// different colours never share exactly the same cut plane (avoids preview z-fighting).
function cut_y(c) = 0.06 * (((c[0] * 3.1 + c[1] * 5.7 + c[2] * 8.3) * 97) % 1);

module cut_half(y0 = 0) translate([-300, -300 + y0, -300]) cube([1200, 300, 600]);

module clip(y0 = 0) {
    if (cutaway_mode == 1) difference() { union() children(); cut_half(y0); }
    else children();
}

// part colour + clip: the colour sits OUTSIDE the difference so cut faces keep the part colour
module pc(c) color(c) clip(cut_y(c)) children();

// slide a sub-assembly along X for the exploded view
module ex(k) translate([explode * k, 0, 0]) children();

// =====================================================================
//  NOSE SECTION  (x = 0 .. 100)
// =====================================================================
NN = 48;
function nose_out(x) = R * sqrt(max(0, 1 - pow((nose_len - x) / nose_len, 2)));
function nose_in(x)  = let(a = nose_len - wall, b = R - wall, u = (nose_len - x) / a)
                       (u >= 1) ? 0 : b * sqrt(1 - u * u);

nose_outer_pts = concat(
    [for (i = [0 : NN]) let(x = nose_len * i / NN) [nose_out(x), x]],
    [[0, nose_len]]
);
nose_inner_pts = concat(
    [for (i = [0 : NN]) let(x = wall + (nose_len - wall) * i / NN) [nose_in(x), x]],
    [[R - wall, nose_len + 1], [0, nose_len + 1]]
);

module nose_shell_full()
    difference() {
        revolve_x(nose_outer_pts);
        revolve_x(nose_inner_pts);
    }

module acoustic_window()
    pc(c_window)
        intersection() {
            nose_shell_full();
            cyl_x(-1, win_len + 1, D + 2);
        }

module transducer() {
    // piezo element array (front of the transducer)
    pc(c_brass)
        for (iy = [-3 : 3], iz = [-3 : 3])
            if (sqrt(iy * iy + iz * iz) * 8 <= 27)
                translate([38, iy * 8, iz * 8]) rotate([0, 90, 0]) cylinder(d = 6, h = 2.5, $fn = 20);
    pc([0.25, 0.25, 0.28]) cyl_x(40, 6, 64);     // face plate   x 40..46
    pc(c_metal)            cyl_x(46, 20, 60);    // housing      x 46..66
    pc(c_dark)                                    // standoffs    x 66..68
        for (sy = [-1, 1], sz = [-1, 1])
            translate([66, sy * 20, sz * 20]) rotate([0, 90, 0]) cylinder(d = 4, h = 2, $fn = 12);
}

module sonar_pcb() {
    pc(c_pcb) cyl_x(68, 1.6, 76);                 // round processing board
    // components on the aft face: [y, z, size_y, size_z, height]
    pc(c_chip)
        for (c = [[-18, -12, 12, 10, 2.5], [-2, -16, 14, 9, 3], [12, -12, 10, 10, 2],
                  [-18,   8,  9, 14, 3],   [4,  10, 16, 8, 2.5], [18,  12,  8,  8, 2]])
            translate([69.6, c[0] - c[2] / 2, c[1] - c[3] / 2]) cube([c[4], c[2], c[3]]);
    pc([1, 1, 1]) translate([69.6, 19, 21]) cube([5, 6, 6]);   // harness connector
}

module nose_harness()
    pc(c_blue) cable([[74, 22, 24], [84, 22, 24], [97, 22, 24]], 3.5);

module nose_section() {
    pc(c_hull)  difference() { nose_shell_full(); cyl_x(-1, win_len + 1, D + 2); }
    pc(c_metal) tube_x(x_j1 - 12, 8, 92.5, 76);   // nose flange    x 88..96
    pc(c_dark)  tube_x(x_j1 - 1, 2, D + 0.8, 94); // seam band at joint 1
    pc(c_metal) tube_x(50, 4, 82, 60);            // transducer mounting collar
    transducer();
    sonar_pcb();
    nose_harness();
}

// =====================================================================
//  BULKHEADS (pressure), O-RINGS, PENETRATORS, FASTENER CIRCLES
// =====================================================================
module bulkhead(xb) {
    // 8 mm plate with two radial O-ring grooves
    pc(c_metal)
        difference() {
            cyl_x(xb, 8, 92);
            for (gx = [xb + 2, xb + 6])
                difference() { cyl_x(gx - 1.6, 3.2, 92.2); cyl_x(gx - 1.7, 3.4, 86); }
        }
    pc(c_oring) for (gx = [xb + 2, xb + 6]) oring(gx, 44.5, 3);
    // cable penetrators
    for (sy = [-1, 1], sz = [-1, 1])
        translate([0, sy * 22, sz * 24]) {
            pc(c_brass) cyl_x(xb - 2, 12, 8, 24);
            pc(c_dark)  { cyl_x(xb - 2.8, 0.8, 5, 24); cyl_x(xb + 10, 0.8, 5, 24); }
        }
}

// ring of 8 bolts on a 84 mm bolt circle; head at xh, 24 mm shank, nut behind
module bolt_ring(xh)
    pc(c_steel)
        for (k = [0 : 7])
            rotate([k * 45, 0, 0]) translate([0, 0, 42]) {
                cyl_x(xh,      3,    6.5, 6);
                cyl_x(xh + 3,  24,   4,   16);
                cyl_x(xh + 27, 3.2,  6.5, 6);
            }

module imu() {
    // board on stand-offs, forward face of the forward bulkhead
    translate([0, 0, -22]) {
        pc(c_pcb)   translate([90, -10, -10]) cube([1.6, 20, 20]);
        pc(c_chip)  translate([88, -4, -4])   cube([2, 8, 8]);
        pc(c_metal) for (sy = [-1, 1], sz = [-1, 1])
            translate([91.6, sy * 7, sz * 7]) rotate([0, 90, 0]) cylinder(d = 4, h = 4.4, $fn = 12);
    }
}

module pressure_sensor()
    translate([0, 0, 22]) {
        pc(c_brass) cyl_x(84, 12, 14, 6);     // hex body
        pc(c_metal) cyl_x(80, 4, 8, 24);      // sensing port
    }

module fwd_bulkhead_group() {
    bulkhead(x_j1 - 4);        // x 96..104
    bolt_ring(x_j1 - 15);      // head x 85, nut x 112
    imu();
    pressure_sensor();
}

module aft_bulkhead_group() {
    bulkhead(x_j2 - 4);        // x 346..354
    bolt_ring(x_j2 - 15);      // head x 335, nut x 362
}

// =====================================================================
//  CENTRAL SECTION  (x = 100 .. 350)
// =====================================================================
module electronics_stack() {
    // three boards, 14 mm pitch
    for (i = [0 : 2]) {
        z0 = (i - 1) * 14;
        pc(c_pcb) translate([122, -24, z0 - 0.8]) cube([100, 48, 1.6]);
        pc(c_chip)
            for (j = [0 : 5])
                translate([128 + j * 15 + (i % 2) * 3, -16 + ((j * 7 + i * 5) % 4) * 10, z0 + 0.8])
                    cube([10, 8, 2 + (j + i) % 3]);
    }
    // stand-offs between boards
    pc(c_metal)
        for (i = [0 : 1], sx = [126, 218], sy = [-18, 18])
            translate([sx, sy, (i - 1) * 14 + 0.8]) cylinder(d = 4, h = 12.4, $fn = 12);
    // connectors on the top board
    pc([1, 1, 1]) translate([124, 16, 14.8]) cube([8, 8, 6]);   // sonar harness
    pc([1, 1, 1]) translate([208, 14, 14.8]) cube([8, 8, 6]);   // battery power
}

module battery_module(z0)
    translate([0, 0, z0]) {
        pc(c_batt)  cyl_x(232, 100, 34);
        pc(c_dark)  for (bx = [244, 318]) cyl_x(bx, 6, 35.4);   // straps
        pc(c_metal) { cyl_x(229, 3, 14, 24); cyl_x(332, 3, 14, 24); }   // terminals
    }

module battery_bay() {
    battery_module(-17.5);
    battery_module( 17.5);
    pc(c_copper) translate([333, -3, -18]) cube([2, 6, 36]);    // series bus bar
}

module rails()
    pc(c_metal)
        for (sy = [-1, 1], sz = [-1, 1])
            translate([0, sy * 28, sz * 20]) {
                cyl_x(104, 242, 5, 16);
                cyl_x(104, 4, 7, 16);
                cyl_x(342, 4, 7, 16);
            }

module central_cables() {
    pc(c_blue)   cable([[104, 22, 24], [114, 22, 24], [128, 20, 18.9]], 3.5);   // sonar -> stack
    pc(c_red)    cable([[232, 10, 22], [226, 16, 22], [212, 18, 18.9]], 3.5);   // battery -> stack
    pc(c_orange) cable([[332, 10, 22], [340, 22, 24], [346, 22, 24]], 3.5);     // battery -> motor
}

module central_section() {
    pc(c_hull)  tube_x(x_j1, mid_len, D, D - 2 * wall);
    pc(c_metal) tube_x(x_j1 + 4, 8, 92.5, 76);        // fwd tube flange  x 104..112
    pc(c_metal) tube_x(x_j2 - 12, 8, 92.5, 76);       // aft tube flange  x 338..346
    pc(c_dark)  tube_x(x_j2 - 1, 2, D + 0.8, 94);     // seam band at joint 2
    electronics_stack();
    battery_bay();
    rails();
    central_cables();
}

// =====================================================================
//  TAIL / PROPULSION SECTION  (x = 350 .. 450)
// =====================================================================
function tail_r(x) = (x <= tail_taper_start) ? R
                   : R - (x - tail_taper_start) * (R - tail_end_r) / (tail_end - tail_taper_start);

tail_pts = [
    [R, x_j2], [R, tail_taper_start], [tail_end_r, tail_end],
    [0, tail_end], [0, tail_end - 6],
    [tail_r(tail_end - 6) - wall, tail_end - 6],
    [R - wall, tail_taper_start], [R - wall, x_j2]
];

module motor() {
    pc(c_dark)  cyl_x(362, 48, 36);                   // motor housing  x 362..410
    pc(c_brass) cyl_x(380, 3, 36.8);                  // winding band
    pc(c_metal) { cyl_x(410, 6, 28); cyl_x(416, 6, 20); }   // end bell + bearing boss
    pc(c_steel) cyl_x(416, 26, 8, 24);                // shaft  x 416..442
    pc(c_dark)  { cyl_x(426, 4, 16, 32); cyl_x(436, 2, 16, 32); }   // shaft seals
    pc(c_brass) translate([368, 8, 10]) cube([6, 6, 6]);            // terminal block
    // motor mount spider (4 arms) to the tail flange
    pc(c_metal)
        for (a = [22.5 : 90 : 292.5])
            rotate([a, 0, 0]) translate([360, -2, 16]) cube([6, 4, 23.5]);
}

// cruciform control fins
fin_x0 = 386; fin_c = 36; fin_sweep = 12; fin_tipc = 20; fin_tip_r = 66; fin_t = 4.5;
module fin() {
    pc(c_fin)
        rotate([90, 0, 0]) linear_extrude(height = fin_t, center = true)
            polygon([[fin_x0,                   tail_r(fin_x0) - 2],
                     [fin_x0 + fin_c,           tail_r(fin_x0 + fin_c) - 2],
                     [fin_x0 + fin_sweep + fin_tipc, fin_tip_r],
                     [fin_x0 + fin_sweep,       fin_tip_r]]);
    pc(c_metal) translate([fin_x0 + 14, 0, 20]) cylinder(d = 4, h = fin_tip_r - 28, $fn = 20);  // pivot shaft
}
module fins() for (a = [0 : 90 : 270]) rotate([a, 0, 0]) fin();

module tail_section() {
    pc(c_hull)
        difference() {
            revolve_x(tail_pts);
            cyl_x(tail_end - 8, 10, 9, 32);              // shaft passage
        }
    pc(c_metal) tube_x(x_j2 + 4, 8, 92.5, 76);        // tail flange  x 354..362
    motor();
    fins();
    pc(c_orange) cable([[354, 22, 24], [364, 22, 24], [370, 12, 13.5]], 3.5);
}

// 3-blade propeller: hub x 438..450, blade tip radius 44 (stays inside the 450 mm envelope)
module propeller()
    translate([438, 0, 0]) rotate([0, 90, 0])
        pc(c_prop) {
            cylinder(d = 20, h = 8, $fn = 40);
            translate([0, 0, 8]) cylinder(d1 = 20, d2 = 8, h = 4, $fn = 40);
            for (k = [0 : 2])
                rotate([0, 0, k * 120])
                    translate([26, 0, 4.5]) rotate([35, 0, 0]) scale([18, 6, 0.9]) sphere(r = 1, $fn = 32);
        }

// =====================================================================
//  ASSEMBLY
// =====================================================================
module auv_assembly() {
    ex(-4)   acoustic_window();
    ex(-3)   nose_section();
    ex(-2)   fwd_bulkhead_group();
    ex(0)    central_section();
    ex(2)    aft_bulkhead_group();
    ex(3)    tail_section();
    ex(4.5)  propeller();
}

module auv_view() auv_assembly();

// =====================================================================
//  BASIC DIMENSION LABELS
// =====================================================================
module dim_h(x1, x2, z, label)
    color("black") {
        translate([x1, -0.3, z - 0.4]) cube([x2 - x1, 0.6, 0.8]);
        for (x = [x1, x2]) translate([x - 0.4, -0.3, z - 4]) cube([0.8, 0.6, 8]);
        translate([(x1 + x2) / 2, -0.3, z - 10]) rotate([90, 0, 0])
            linear_extrude(0.6) text(label, size = 6, halign = "center");
    }

module dim_v(x, z1, z2, label)
    color("black") {
        translate([x - 0.4, -0.3, z1]) cube([0.8, 0.6, z2 - z1]);
        for (z = [z1, z2]) translate([x - 4, -0.3, z - 0.4]) cube([8, 0.6, 0.8]);
        translate([x - 8, -0.3, (z1 + z2) / 2 - 3]) rotate([90, 0, 0])
            linear_extrude(0.6) text(label, size = 6, halign = "right");
    }

module dimensions() {
    dim_h(0,      L,      -92, "Length 450 mm");
    dim_h(0,      x_j1,   -76, "Nose 100");
    dim_h(x_j1,   x_j2,   -76, "Central 250");
    dim_h(x_j2,   L,      -76, "Tail 100");
    dim_v(-12, -R, R, "D 100");
}

// =====================================================================
auv_view();
if (show_dimensions == 1) dimensions();
