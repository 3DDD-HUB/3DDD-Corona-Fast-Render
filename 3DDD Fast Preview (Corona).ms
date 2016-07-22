

try(closeRolloutFloater fFastRender) catch()
global fFastRender = newRolloutFloater "3DDD Fast Preview (Corona)" 250 550

global szVer = "1.0.0"
global lightHDR = undefined
global reflectHDR = undefined
global corona = undefined
global outputMap = compositeTextureMap()

global _rStep0
global _rStep1

rollout _rStep0  "Basic Setup"
(
	button btnSetupScene "Setup Scene" height: 35 width: 230
		
	group "Light"
	(		
		spinner spnLightHDR "" across: 2 align: #left range: [0, 360, 0] type: #integer scale: 1.0 
		label lblDegree "°" align: #left offset: [-44, 0]
		label lblStart "0°" align: #left across: 2
		label lblStop "360°" align: #right
		slider sldLightHDR "" ticks: 36 range:[0,360,0] type: #integer
		button btnLightHDR "None"
	)
	
	group "Reflections"
	(
		checkbox cbxUseReflect "Use Reflect HDR"
		spinner spnReflectHDR "" across: 2 align: #left range: [0, 360, 0] type: #integer scale: 1.0 
		label lblDegree2 "°" align: #left offset: [-44, 0]
		label lblStart2 "0°" align: #left across: 2
		label lblStop2 "360°" align: #right
		slider sldReflectHDR "" ticks: 36 range:[0,360,0] type: #integer
		button btnReflectHDR "None"
	)
	
	fn useSettings k p w =
	(	
		settingsFile = getThisScriptFilename() + ".ini"
		
		v = maxVersion()
		v = 2000 + ((v[1] / 1000) - 2)
		
		case w of
		(
			"r":
			(
				s = getINISetting settingsFile (v as string) k
				case p of
				(
					"int": return s as integer
					"float": return s as float
					"bool": if s == "true" or s.count < 1 then true else false
					"bool_not": if s == "true" then true else false
					
					default: return s
				)
			)
			default: return setINISetting settingsFile (v as string) k (p as string)
		)
	)
	
	-------------------------------------------------
	
	fn delVFB_Elements =
	(
		re = maxOps.GetCurRenderElementMgr()
		re.RemoveAllRenderElements()
	)

	fn addElement el =
	(		
		re = maxOps.GetCurRenderElementMgr()				
		re.AddRenderElement el	
	)

	fn addVFB_Elements = 
	(
		delVFB_Elements()

		renderElements = #()
		
		append renderElements (CESSENTIAL_Direct())
		append renderElements (CESSENTIAL_Reflect())
		append renderElements (CESSENTIAL_Refract())
		append renderElements (CShading_Albedo())
		
		cm = CTexmap()	
		cm.texmap = CoronaAO()	
		cm.overrideBackground = true
		cm.overrideBackgroundColor = white
		cm.texmap.maxDistance = (units.decodeValue "15.0cm")
				
		append renderElements cm
		
		for el in renderElements do addElement el
	)
		
	-------------------------------------------------
	
	fn disableUI d btn: true =
	(
		for i in _rStep0.controls do i.enabled = d
				
		_rStep0.btnSetupScene.enabled = btn
	)
	
	fn isCorona = 
	(
		r = renderers.current

		if(classOf r == CoronaRenderer) do return r
		return undefined
	)
	
	fn defaultView = 
	(
		select geometry
				
		viewport.setType #view_front
		viewport.setType #view_persp_user 		
					
		theAxis = (viewport.getTM()).row1	
		viewport.rotate (quat 20 theAxis)
	
		theAxis = (viewport.getTM()).row3
		viewport.rotate (quat 40 theAxis)
		
		max zoomext sel
		viewport.zoom 0.8
		
		displaySafeFrames = true	
			
		--c = freeCamera transform:(inverse(viewport.getTM())) fov: 55	
		--viewport.setCamera c
	)
	
	fn angeToOffset a = 1.0 / (360.0 / a) 
	fn offsetToAngle o = 360.0 * o
	fn getAngle a = ((a as integer) as string) + "°"
	
	fn setOffset b o =
	(
		case classOf b of
		(
			CoronaBitmap: b.uvwOffset = [o, 0, 0]
			bitmapTex: b.coords.U_Offset = o
		)
	)
	
	fn getOffset h =
	(
		case classOf h of
		(
			CoronaBitmap: return h.uvwOffset[1]
			bitmapTex: return h.coords.U_Offset
			default: return 0.0
		)
	)		
	
	fn getHDR h =
	(
		case classOf h of
		(
			CoronaBitmap: return h
			bitmapTex: return h
			colorCorrection: return h.map
			default: return undefined
		)	
	)
	
	fn rotateHDR b a = 
	(
		if(b == undefined) do return false
		o = angeToOffset a
			
		h = getHDR b
		if(h != undefined) do setOffset h o				
	)
		
	fn loadHDR = 
	(
		if(corona.bg_source != 1) do return false
			
		h = getHDR corona.bg_texmap
		if(h != undefined) do 
		(
			btnLightHDR.caption = filenameFromPath h.filename
			
			o = getOffset h
			spnLightHDR.value = offsetToAngle o
			sldLightHDR.value = offsetToAngle o
		)
	
		h = getHDR	 corona.bg_texmapReflect
		if(h != undefined) do 
		(
			btnReflectHDR.caption = filenameFromPath h.filename	
			
			o = getOffset h
			spnReflectHDR.value = offsetToAngle o 
			sldReflectHDR.value = offsetToAngle o
		)
		
		cbxUseReflect.checked = corona.bg_overrideReflect
	)
	
	fn setHDRI =
	(
		f = getFilenamePath  (getThisScriptFilename ()) + @"hdri\" 
		lightHDRPath = f + "light.hdr" 
		reflectHDRPath = f + "reflect.hdr" 
		
		corona.bg_source = 1
				
		f1 = useSettings "LIGHT_HDR" "str" "r"	
		f2 = useSettings "REFLECT_HDR" "str" "r"	
			
		lightHDRPath = if(f1 != "")	then f1 else lightHDRPath
		reflectHDRPath = if(f2 != "") then f2 else reflectHDRPath
			
		if(doesFileExist lightHDRPath) do
		(
			corona.bg_overrideDirect = true
			corona.bg_colorDirect = white
			
			lightHDR = CoronaBitmap()
			lightHDR.filename = lightHDRPath
			corona.bg_texmap = lightHDR
				
			a = useSettings "LIGHT_HDR_ANGLE" "float" "r"						
			rotateHDR (corona.bg_texmapReflect) a						
		)
		
		if(doesFileExist reflectHDRPath) do
		(
			corona.bg_overrideReflect = true			
			reflectHDR = CoronaBitmap()
			reflectHDR.filename = reflectHDRPath
			corona.bg_texmapReflect = reflectHDR
			
			a = useSettings "REFLECT_HDR_ANGLE" "float" "r"						
			rotateHDR (corona.bg_texmapReflect) a					
		)
		
		loadHDR()
	)
	
	fn useReflect =
	(
		r = useSettings "REFLECT_HDR_ON" "bool_not" "r"	
		cbxUseReflect.checked = r
		corona.bg_overrideReflect = r
	)
		
	on btnLightHDR pressed do
	(
		f = getOpenFileName  caption: "Select Light HDR" types: "*.hdr|*.hdr|*.exr|*.exr"
		if(f == undefined) do return false
		
		useSettings "LIGHT_HDR" f "w"	

		setHDRI()
	)
	
	on btnReflectHDR pressed do
	(
		f = getOpenFileName  caption: "Select Reflect HDR" types: "*.hdr|*.hdr|*.exr|*.exr"
		if(f == undefined) do return false
		
		useSettings "REFLECT_HDR" f "w"	

		setHDRI()
	)
	
	on cbxUseReflect changed s do
	(
		useSettings "REFLECT_HDR_ON" s "w"
		
		useReflect()
	)
	
	on _rStep0	open do
	(			
		corona = isCorona()	
		if(corona == undefined) do 
		(
			closeRolloutFloater fFastRender
			return messageBox "Please assign Corona Renderer" title: "Warning!"
		)

		loadHDR()
	)
		
	on btnSetupScene pressed do
	(
		
		if(corona == undefined) do return messageBox "Please assign Corona Renderer" title: "Warning!"
				
		defaultView()
					
		renderWidth = 640
		renderHeight = 640
				
		setHDRI()
		
		useReflect()
				
		addVFB_Elements()
				
		corona.denoise_filterType = 2
		corona.denoise_blendAmount = 0.5
		
		corona.colorMap_simpleExposure = 1.0
		corona.colorMap_highlightCompression = 2.0
		
		startInteractive()
	)
	
	on sldLightHDR changed a do
	(					
		spnLightHDR.value = a 
		
		rotateHDR (corona.bg_texmap) a
		useSettings "LIGHT_HDR_ANGLE" a "w"
	)
	
	on sldReflectHDR changed a do
	(					
		spnReflectHDR.value = a 
		
		
		rotateHDR (corona.bg_texmapReflect) a
		useSettings "REFLECT_HDR_ANGLE" a "w"
	)
	
	on spnReflectHDR changed a do
	(
		sldReflectHDR.value = a
		
		rotateHDR (corona.bg_texmapReflect) a
		useSettings "REFLECT_HDR_ANGLE" a "w"
	)
	
	on spnLightHDR changed a do
	(
		sldLightHDR.value = a
		
		rotateHDR (corona.bg_texmap) a
		useSettings "LIGHT_HDR_ANGLE" a "w"
	)
)

rollout _rStep1  "Render / PostProcess"
(	
	
	button btnStartInteractive "Start Interactive"
	button btnStartRender "Start Render" height: 35 width: 230
	
	button btnShowFinal "Show Final Result" checked: true
	
	fn getVFB c: 0 = 
	(	
		f = @"c:\temp\fast-preview\"
		makeDir f
			
		b = CoronaRenderer.CoronaFp.getVfbContent c true true
		b.filename = f + c as string  + ".jpg"
		save b
		close b
		
		bt = Bitmaptexture()	
		bt.bitmap = b
			
		return  bt
	)
	
	fn clearCache =
	(
		f = @"c:\temp\fast-preview\"
		d = getFiles (f + "*")
		for i in d do deleteFile i
	)
	
	fn showFinal =
	(
		a = getVFB c:1
		main = getVFB c:0

		-- Beauty / None
		--outputMap = compositeTextureMap()
		outputMap.mapList[1] = main

		-- Direct Light / SoftLight
		l = 2
		outputMap.mapList[l] = getVFB c: l
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.blendMode[l] = 15
		outputMap.opacity[l] = 15
		outputMap.mask[l] = a

		-- Reflect / Screen
		l = 3
		outputMap.mapList[l] = ColorCorrection()
		outputMap.mapList[l].map = getVFB c: l			
		outputMap.mapList[l].map.coords.blur = 0.01
		outputMap.mapList[l].lightnessMode = 1
		outputMap.mapList[l].liftRGB = -0.35			
		outputMap.blendMode[l] = 9
		outputMap.opacity[l] = 100
		outputMap.mask[l] = a

		-- Refract / Screen
		l = 4
		outputMap.mapList[l] = getVFB c: l
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.blendMode[l] = 9
		outputMap.opacity[l] = 50
		outputMap.mask[l] = a
		
		-- Albedo / Overlay
		l = 5
		outputMap.mapList[l] = getVFB c: l
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.blendMode[l] = 14
		outputMap.opacity[l] = 25
		outputMap.mask[l] = a

		-- AO / Multiply
		l = 6
		outputMap.mapList[l] = getVFB c: l
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.blendMode[l] = 5
		outputMap.opacity[l] = 25
		outputMap.mask[l] = a
		/*
		-- CA / Lighten
		l = 7
		outputMap.mapList[l] = ColorCorrection()
		outputMap.mapList[l].map = copy main
		outputMap.mapList[l].map.coords.U_Offset = 0.0015		
		outputMap.mapList[l].lightnessMode = 1
		outputMap.mapList[l].enableR = on		
		outputMap.mapList[l].enableG = on		
		outputMap.mapList[l].enableB = on		
		outputMap.mapList[l].gainG = 0		
		outputMap.mapList[l].gainB = 0		
		outputMap.blendMode[l] = 8
		outputMap.opacity[l] = 40
		
		l = 8
		outputMap.mapList[l] = ColorCorrection()
		outputMap.mapList[l].map = copy main
		outputMap.mapList[l].map.coords.U_Offset = -0.0015			
		outputMap.mapList[l].lightnessMode = 1
		outputMap.mapList[l].enableR = on		
		outputMap.mapList[l].enableG = on		
		outputMap.mapList[l].enableB = on		
		outputMap.mapList[l].gainR = 0			
		outputMap.blendMode[l] = 8
		outputMap.opacity[l] = 40
		*/

		outRender = renderMap outputMap size:[640,640] filter: true scale: 1.0
		display outRender
		
		clearCache()
				
		/*rollout rFinalResult  "Post Process" 
		(
			bitmap btmOutRender width: 640 height: 640 offset: [0, 35]
			timer tmrUpdateOutRender "" interval: 3000 
			
			on rFinalResult open do
			(
				
			)
			
			on rFinalResult close do
			(
				tmrUpdateOutRender.active = false
			)
				
			
			on tmrUpdateOutRender tick do
			(			
				
			)			
		)
		
		createDialog rFinalResult 640 (640 + 35)*/
	)
	
	global isRendering = true
	fn stopRender = CoronaRenderer.CoronaFp.stopRender()
	fn startRender = CoronaRenderer.CoronaFp.resumeRender()
	fn startInteractive = CoronaRenderer.CoronaFp.startInteractive()
	
	on btnStartRender pressed do startRender()	
	
	on btnStartInteractive pressed do startInteractive()
	
	on btnShowFinal pressed do showFinal()
)

rollout _rAbout "About" 
(
	local c = color 200 200 200 
	
	label lbl2 "3DDD Fast Preview (Corona)" 
	label lbl3 szVer 
	
	label lbl5 "by MastaMan" 
	label lbl6 "" 
		
	hyperLink href2 "Script Home" address: "http://3ddd.ru/forum/thread/show/skript_prepare_model_3ddd/" align: #center hoverColor: c visitedColor: c
	hyperLink href "http://3ddd.ru" address: "http://3ddd.ru" align: #center hoverColor: c visitedColor: c
)

addRollout _rStep0 fFastRender rolledUp:false
addRollout _rStep1 fFastRender rolledUp:false
addRollout _rAbout fFastRender rolledUp:true 
/*

addVFB_Elements()



a = getVFB c:1

-- Beauty / None
outputMap = compositeTextureMap()
outputMap.mapList[1] = getVFB c:0

-- Direct Light / SoftLight
outputMap.mapList[2] = getVFB c: 2
outputMap.blendMode[2] = 15
outputMap.opacity[2] = 35.0
outputMap.mask[2] = a

-- Reflect / Screen
outputMap.mapList[3] = getVFB c: 3
outputMap.mapList[3].output.rgb_offset = -0.25
outputMap.blendMode[3] = 9
outputMap.opacity[3] = 50.0
outputMap.mask[3] = a

-- Refract / Screen
outputMap.mapList[4] = getVFB c: 4
outputMap.blendMode[4] = 9
outputMap.opacity[4] = 15.0
outputMap.mask[4] = a

-- AO / Multiply
outputMap.mapList[5] = getVFB c: 5
outputMap.blendMode[5] = 5
outputMap.opacity[5] = 35
outputMap.mask[5] = a


outRender = renderMap outputMap size:[640,640] filter: true scale: 1.0
display outRender

*/