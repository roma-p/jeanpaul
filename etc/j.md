
CORRECT IMG: func height / width forced at u8
ADD DRAW PX HELPER IN IMG: X / Y / COLOR

focal_center = get_focal_plane_center(camera)
for px in image:
  direction = get_direction(camera, focal_center, px)
  vec position;
  int distance
  int disrance_min 
  for obj in obj_list:
    if ray_intersect():
      if distance > distance_min...




- matrice: 
  - obj
    - [ ] model: decris position dans l'espace. from espace obj -> espace du monde
  - camera
    - [ ] view: projette dans l'espace de vue de ta camera. -> espace du monde vers espace de ta camera
    - [ ] project: 3D vers 2D

- [ ] create repo
- [ ] how to test? test create_matrix
- [ ] missing defer...
- [ ] draw a cube of any size on an image (before circle...)
- [ ] add things to draw on the terminal to start.
