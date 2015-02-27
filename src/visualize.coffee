_meshPool = []

module.exports =
  buildDataVizGeometries: ( linearData, countryData ) ->
    loadLayer = document.getElementById 'loading'
    count = 0

    for set in linearData
      exporterName = set.src.toUpperCase()
      importerName = set.dest.toUpperCase()

      exporter = countryData[exporterName]
      importer = countryData[importerName]

      # we couldn't find the country, it wasn't in our list...
      if not exporter? or not importer?
        continue

      # visualize this event
      set.lineGeometry = makeConnectionLineGeometry exporter, importer, set.v, set.wc

    loadLayer.style.display = 'none'
    return

  initMeshPool: ( poolSize ) ->
    _meshPool.push new ParticleMesh() for i in [0...poolSize]

  getVisualizedMesh: ( linearData, callback ) ->
    return null if not linearData.lineGeometry?

    _getMeshFromPool ( meshObj ) ->
      # merge it all together
      meshObj.linesGeo.merge linearData.lineGeometry
      points = linearData.lineGeometry.vertices
      point = points[0]
      particle = point.clone()
      particle.moveIndex = 0
      particle.nextIndex = 1
      particle.lerpN = 0
      particle.path = points
      particle.size = meshObj.particleSize
      meshObj.particlesGeo.vertices.push particle

      # set the colour
      meshObj.setParticleColour linearData.colour

      return callback meshObj.splineOutline

  selectVisualization: ( linearData ) ->
    # clear off the country's internally held color data we used from last highlight
    for country in countryData
      country.exportedAmount = 0
      country.importedAmount = 0
      country.mapColor = 0

    # build the meshes. One for each entry in our data
    for data in linearData
      getVisualizedMesh data, _addMeshToViz

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# HELPER METHODS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

_addMeshToViz = ( mesh ) ->
  visualizationMesh.add mesh if mesh?

_getMeshFromPool = ( callback ) ->
  if _meshPool.length > 0
    callback _meshPool.pop()
  else
    window.setTimeout _getMeshFromPool, 500, callback

_returnMeshToPool: ( mesh ) ->
  # clean up the two geometries
  mesh.linesGeo.vertices = []
  mesh.particlesGeo.vertices = []
  mesh.pSystem.systemComplete = false

  # have to remove from the scene or else bad things happen. 'scene' is leaked
  # into this scope from main.js
  scene.remove mesh.splineOutline

  _meshPool.push mesh

class ParticleMesh
  constructor: ->
    this.linesGeo = new THREE.Geometry()
    this.particlesGeo = new THREE.Geometry()
    this.particleColor = COLOUR_MAP.r
    this.particleSize = 150

    this.lineMat = new THREE.LineBasicMaterial
      color: 0xffffff
      opacity: 0.0
      blending: THREE.AdditiveBlending
      transparent: true
      depthWrite: false
      vertexColors: false
      linewidth: 1
    this.splineOutline = new THREE.Line null, this.lineMat

    this.shaderMaterial = new THREE.PointCloudMaterial
      map:          THREE.ImageUtils.loadTexture "images/particleB.png"
      size:         this.particleSize
      blending:     THREE.AdditiveBlending
      depthTest:    true
      depthWrite:   false
      transparent:  true
      color:        this.particleColor
    this.pSystem = new THREE.PointCloud null, this.shaderMaterial

    this.splineOutline.renderDepth = false
    this.pSystem.dynamic = true
    this.pSystem.systemComplete = false # So we can know when to re-pool this mesh
    this.splineOutline.add this.pSystem
    this.splineOutline.geometry = this.linesGeo
    this.pSystem.geometry = this.particlesGeo

    this.pSystem.addEventListener( 'ParticleSystemComplete', _returnMeshToPool.bind( this, this ) )

    # This update method is what actually gets our points moving across the scene.
    # Once the point has finished its path, this method will emit a "ParticleSystemComplete"
    # event, to allow us to re-pool the mesh.
    this.pSystem.update = ->
      #Simplified this as our particle geometry will only ever have one point
      particle = this.geometry.vertices[0]

      # no point doing all the calculations if the particle is already done
      return if this.systemComplete? or not particle

      path = particle.path
      moveLength = path.length

      particle.lerpN += 0.15
      if particle.lerpN > 1
        particle.lerpN = 0
        particle.moveIndex = particle.nextIndex
        particle.nextIndex++
        if particle.nextIndex >= path.length
          particle.moveIndex = 0
          particle.nextIndex = 0

          this.systemComplete = true
          this.dispatchEvent { type: 'ParticleSystemComplete' }
          return

      currentPoint = path[particle.moveIndex]
      nextPoint = path[particle.nextIndex]

      particle.copy currentPoint
      particle.lerp nextPoint, particle.lerpN

      this.geometry.verticesNeedUpdate = true

  setParticleColour: ( colourStr ) ->
    colour = COLOUR_MAP[colourStr]
    colour = COLOUR_MAP.r if not colour

    this.particleColor = colour
    this.shaderMaterial.color = colour