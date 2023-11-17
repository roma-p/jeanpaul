
Perfo renderer empty (monothread): 
 1 - "implementation tous les AOV dans un px, 30 AOV max"
  -> accé à tous les pixels pr tous les aov + écritures de tous les AOV, debug.
  126s
  -> accé à tous les pixels pr tous les aov, pas d'écriture de fichiers.
  2.8s 
  
essayer en release mode.


--- 

x 1 multiplier color to fix...
x 2 corriger normal map entre -1 et 1...
- 3 plusieurs light?
- 4 light decay: constant / quadratic.
- 5 ajouter ambient.
- 6 ajouter plan.

---

x 1 gerer la direction de la camera en 001,
x 2 changer en 00-1 et corriger les rendus.
x 3 CLI !
x 4 on peut passer à la 3D.


---

Maintenant que la partie "parser" est censée fonctionner...
- 1 zigligs du début à la fin...
- 2 ajouter test Us avec fichier mal formatté -> erreur de parser à detecter!
- 3 modifier les shapes comme ds l'exemple...
- 4 detecter direction de la camera à partir de la matrice de transformation: (-1 x tmatrix)
- 5 revoir le system de materiaux? 
- 5 ajouter build de scene dans le parser. (implique surement bcp de saloperies...)
- 6 ajouter une cli basic... wala jpp scene.jpp picture.ppm
- 7 finalement débug: les axes d'images, x,y,z ... ET FINALEMENT AVANCER....

-----

- objectType -> category
- add type and hashmap to str to hasmap
- add object contructor generic (get rid of 'create_sphere' ... -> will be in scene.
- and about properties? I don't know...

-----

- normal: deux bugs... method in itself can segfault...
          position not given to get_normal_at_position...
? d'abord corriger normal? et inchallah ca corrige l'autre?
- Problem de epsilon....

- COLOR as single file.
- Method to add object to scene: Scene.create() ? or Scene.add() generic?

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
