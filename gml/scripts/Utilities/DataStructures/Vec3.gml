function Vec3(_x, _y, _z) {
  _x = _x == undefined ? 0 : _x;
  _y = _y == undefined ? 0 : _y;
  _z = _z == undefined ? 0 : _z;
  return new __Vec3(_x, _y, _z);
}

function __Vec3(_x, _y, _z) constructor {
  x = _x;
  y = _y;
    z = _z;
}
