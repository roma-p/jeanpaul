
# JeanPaul Prototype 1

This first prototype is a CPU only, monothreaded simple ray tracer.
It is mostly based on this [article](https://matklad.github.io/2022/12/31/raytracer-construction-kit.html) by Alex Kladov.

![render](../historic/proto_1_r7.png)

To build it: 

```
> cd proto_1
> zig build
```

This JeanPaul prototype defines its own scene description format: ".jpp" files 
(which stands for "Jean Paul Parameters"). Its syntax is heavily inspired by Arnold ".ass" format.

It can render image in .ppm format using the "wala" binary: 

```
> wala jpp scene.jpp image.ppm
```

This prototype only supports implicit sphere and plane, perpective camera and point lights (called "Omni" as they are named in Cinema4d).

```
scene
{
render_camera "camera_main"
samples 7   # -> 2^7 samples per pixel.
bounces 6   # -> each ray will bounce up to 6 times.
resolution ! V 2
1024 768
}

object.CameraPersp
{
name "camera_main"
focal_length 10
field_of_view 60
tmatrix ! M 4 4
1 0 0 5
0 1 0 0
0 0 1 47
0 0 0 1
}

object.ImplicitSphere
{
name "sphere_grey"
material "lambert_grey"
radius 10
tmatrix ! M 4 4
1 0 0 0
0 1 0 -2
0 0 1 0
0 0 0 1
}

object.LightOmni  # point light
{
name "yellow_light"
tmatrix ! M 4 4
1 0 0 20
0 1 0 11
0 0 1 12
0 0 0 1
color ! V 3
1 1 0.5
intensity 1.3
exposition 8
decay_rate "Quadratic"
}

material.Lambert
{
name "lambert_grey"
kd_intensity 0.7
kd_color ! V 3
0.5 0.5 0.5
diff_reflection 0.8
}
```


The ray tracing process of this prototypes goes has follow:

- for every pixel of the screen, shoot a ray from the camera.
- if an object is hit: will compute the color of the pixel by shooting obstruction rays from the hit position to every point light of the scene.
- the ray will then bounce in a random direction contained by the hemisphere colinear with the normal of the surface of the object. If this ray hit something, it will shoot obstruction rays to every point light of the scene to modify the color of the pixel.
- the operation is repeated for as many "bounce" define in the scene or if nothing is hit.
