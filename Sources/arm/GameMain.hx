package arm;

import kex.vox.VoxelTools;
import kex.vox.Voxel;
import kex.vox.Triangle;
import kex.vox.MeshFactory;

import iron.Scene;
import iron.data.SceneFormat;
import iron.data.MeshData;
import iron.data.MaterialData;
import iron.data.Data;
import iron.object.Transform;
import iron.object.MeshObject;
import iron.system.Input;
import iron.math.Vec4;
import iron.math.RayCaster;
import iron.math.Ray;
import armory.trait.physics.bullet.PhysicsWorld;
import armory.trait.physics.bullet.RigidBody;

import kha.input.Mouse;
import kha.input.Keyboard;
import kha.input.KeyCode;



class VoxelWorld {
	public var worldName:String;
	public var chunks:Array<VoxelChunk> = new Array();

	/**
		@param worldName The name of the world used to save and load world data
		@param chunkSize The diameter of a chunk measured in voxels
		@param worldDiameter The world diameter meansured in chunks
	**/
	public function new(worldName:String, chunkSize:Int, worldDiameter:Vec4) {

	}

	public function generateLandscape() {
		
	}
}

class VoxelChunk {
	var voxels:Array<Voxel>;
	var meshData:MeshData;
	var meshObject:MeshObject;
	var transform:Transform;
	var materials:haxe.ds.Vector<MaterialData>;

	public function new(center:Vec4, chunkSize:Vec4, voxels:Array<Voxel> = null) {
		this.transform = new Transform(null);
		transform.loc = center != null ? center : new Vec4(0, 0, 0);
		transform.dim = chunkSize != null ? chunkSize : new Vec4(7, 7, 7);
		this.voxels = voxels != null ? voxels : new Array<Voxel>();
	}

	private function getVoxelTransform(voxel:Voxel) {
		if (voxel == null) {return null;}
		var t = new Transform(null);
		t.loc = new Vec4(
			voxel.x + this.transform.loc.x,
			voxel.y + this.transform.loc.y,
			voxel.z + this.transform.loc.z
		);
		t.dim = new Vec4(1, 1, 1);
		return t;
	}

	private function newVoxelAtLocation(loc:Vec4):Voxel {
		if (transform == null) {return null;}
		return cast {
			x: Math.round(loc.x) - this.transform.loc.x,
			y: Math.round(loc.y) - this.transform.loc.y,
			z: Math.round(loc.z) - this.transform.loc.z,
			color: {r:256,g:0,b:256,a:256}
		}
	}

	private function voxelOutOfBounds(voxel:Voxel):Bool {
		if (Math.abs(voxel.x) > this.transform.dim.x/2 ||
			Math.abs(voxel.y) > this.transform.dim.y/2 ||
			Math.abs(voxel.z) > this.transform.dim.z/2) {
				return true;
		} else {
			return false;
		}
	}

	public function generateVoxelMesh(done:Void->Void = null) {
		// Re-generate Voxel Mesh
		var voxelMesh:Array<Triangle> = null;
		voxelMesh = VoxelTools.newVoxelMesh(this.voxels);

		// Generate new Iron Mesh Data
		var ironMesh:TMeshData = MeshFactory.createRawIronMeshData(
			voxelMesh,
			"KexIronMesh",
			0,
			0,
			0
		);

		// Remove existing voxel mesh
		if (this.meshObject != null) {
			Scene.active.meshes.remove(this.meshObject);
			this.meshData.delete();
		}

		// Update Mesh Data instance
		new MeshData(ironMesh, function(data:MeshData) {
			// Assign loaded MeshData
			this.meshData = data;
			// Calculate bounding box
			this.meshData.geom.calculateAABB();

			if (this.materials == null) {
				// Load Material From scene
				Data.getMaterial("Scene", "DefaultBlockMat", function(data:MaterialData) {
					this.materials = haxe.ds.Vector.fromData([data]);
					if (done != null) {
						done();
					}
				});
			}
		});
	}

	public function spawnVoxelMesh() {
		// Re-spawn new voxel mesh
		this.meshObject = Scene.active.addMeshObject(meshData, materials);
		meshObject.transform.loc.setFrom(this.transform.loc);
		meshObject.transform.buildMatrix();
		meshObject.transform.dim.setFrom(this.transform.dim);
	}

	public function breakBlockUnderMouse(x:Int, y:Int) {
		var clickedVoxel = getVoxelUnderMouse(x,y);
		if (clickedVoxel == null) {return;}
		this.voxels.remove(clickedVoxel);

		generateVoxelMesh();
		spawnVoxelMesh();
	}

	public function placeBlockUnderMouse(x:Int, y:Int) {
		var clickRay = RayCaster.getRay(x, y, Scene.active.camera);
		var clickedVoxel = getVoxelUnderMouse(x,y);
		if (clickedVoxel == null) {return;}
		var t = getVoxelTransform(clickedVoxel);
		var clickLoc = clickRay.intersectBox(t.loc, t.dim);

		var placementRay = new Ray(clickLoc, Scene.active.camera.transform.loc);
		var placementPos = placementRay.at(0.01);
		
		var newVoxel = newVoxelAtLocation(placementPos);

		if (!voxelOutOfBounds(newVoxel)) {
			this.voxels.push(newVoxel);
			generateVoxelMesh();
			spawnVoxelMesh();
		}
	}

	public function getVoxelUnderMouse(mouseX:Int, mouseY:Int) {
		var clickRay = RayCaster.getRay(mouseX, mouseY, Scene.active.camera);
		var closest:Voxel = null;

		// Get blocks under mouse click
		var intersections = [];
		for (voxel in this.voxels) {
			var t = getVoxelTransform(voxel);
			if (clickRay.intersectsBox(t.loc, t.dim)) {
				intersections.push(voxel);
			}
		}

		// Get closest block to mouse click
		if (intersections.length != 0) {
			var minDist:Float = std.Math.POSITIVE_INFINITY;
			for (voxel in intersections) {
				var dist = Vec4.distance(getVoxelTransform(voxel).loc, Scene.active.camera.transform.loc);
				if (dist < minDist) {
					minDist = dist;
					closest = voxel;
				}
			}
		}

		return closest;
	}
}

class GameMain extends iron.Trait {
	var chunk1:VoxelChunk;
 	
	public function new() {
		super();

		// Set mouse event listeners
		notifyOnInit(function() {
			Mouse.get().notify(onMouseDown, onMouseUp, onMouseMove, onMouseWheel);
			Keyboard.get().notify(onKeyDown, onKeyUp);
		});

		notifyOnRemove(function() {
			// Trait or its object is removed, remove event listeners
			Mouse.get().remove(onMouseDown, onMouseUp, onMouseMove, onMouseWheel);
			Keyboard.get().remove(onKeyDown, onKeyUp, null);
		});

		// Create array of voxels
		var voxels = [
			{x:0, y:0, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:0, y:1, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:0, y:3, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:-1, y:2, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:1, y:2, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:-3, y:2, z:2, color: {r:256,g:0,b:256,a:256}},
			{x:-3, y:2, z:1, color: {r:256,g:0,b:256,a:256}},
			{x:3, y:2, z:1, color: {r:256,g:0,b:256,a:256}},
		];

		this.chunk1 = new VoxelChunk(new Vec4(0, 7, 0), new Vec4(7,7,7), cast voxels);
		chunk1.generateVoxelMesh();
		notifyOnInit(init);
	}

	function init() {
		// Spawn voxel chunk
		this.chunk1.spawnVoxelMesh();
	}

	function onMouseDown(button: Int, x: Int, y: Int) {
		if (button == 0) {
			this.chunk1.breakBlockUnderMouse(x, y);
		} else if (button == 1) {
			this.chunk1.placeBlockUnderMouse(x, y);
		}
	}

	function onMouseUp(button: Int, x: Int, y: Int) { }
	function onMouseMove(x: Int, y: Int, movementX: Int, movementY: Int) { }
	function onMouseWheel(delta: Int) { }

	function onKeyDown(key:KeyCode) {

		function handleSpacebar() {
			trace("Spacebar");
		}

		switch (key) {
			case Space: handleSpacebar();
			default:
		}
	}

	function onKeyUp(key:KeyCode) {}
}
