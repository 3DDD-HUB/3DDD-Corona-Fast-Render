
try(closeRolloutFloater fFastRender) catch()
global fFastRender = newRolloutFloater "Fast Preview" 250 880

global szVer = "1.0.0"
global lightHDR = undefined
global reflectHDR = undefined
global corona = undefined
global outputMap = compositeTextureMap()

global _rStep0
global _rStep1
global _rStep2

global 	blendOptions = #(
		"Normal",
		"Average",
		"Addition",
		"Subtract",
		"Darken",
		"Multiply",
		"Color Burn",
		"Linear Burn",
		"Lighten",
		"Screen",
		"Color Dodge",
		"Linear Dodge",
		"Spotlight",
		"Spotlight Blend",
		"Overlay",
		"Soft Light",
		"Hard Light",
		"Pin Light",
		"Hard Mix",
		"Difference",
		"Exclusion",
		"Hue",
		"Saturation",
		"Color",
		"Value"
	 ) 

rollout _rStep0  "Basic Setup"
(
	button btnSetupScene "Setup Scene" height: 35 width: 230
		
	group "Light"
	(		
		spinner spnLightHDR "Angle:" across: 2 align: #left range: [0, 360, 0] type:#integer scale: 1.0 
		spinner spnLightHDR_Mult "Mult.:" align: #right range: [0.0, 9999.0, 1.0]  type:#float scale: 0.1  
		label lblStart "0°" align: #left across: 2
		label lblStop "360°" align: #right
		slider sldLightHDR "" ticks: 36 range:[0,360,0] type: #integer
		button btnLightHDR "None"
	)
	
	group "Reflections"
	(
		checkbox cbxUseReflect "Use Reflect HDR"
		spinner spnReflectHDR "Angle:" across: 2 align: #left range: [0, 360, 0] type: #integer scale: 1.0 		
		spinner spnReflectHDR_Mult "Mult.:"align: #right range: [0.0, 9999.0, 1.0]  type:#float scale: 0.1  
		label lblStart2 "0°" align: #left across: 2
		label lblStop2 "360°" align: #right
		slider sldReflectHDR "" ticks: 36 range:[0,360,0] type: #integer
		button btnReflectHDR "None"
	)
	
	timer tmrRotateLightHDR "" active: false interval: 100
	timer tmrRotateReflectHDR "" active: false interval: 100
	
	fn enableReflections =
	(
		c = cbxUseReflect.checked
		spnReflectHDR.enabled = c
		spnReflectHDR_Mult.enabled = c
		lblStart2.enabled = c
		lblStop2.enabled = c
		sldReflectHDR.enabled = c
		btnReflectHDR.enabled = c
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
		cm.texmap.maxDistance = (units.decodeValue "8.0cm")
				
		append renderElements cm
		
		for el in renderElements do addElement el
	)
		
	-------------------------------------------------
	
	fn disableUI d =
	(
		for i in _rStep0.controls do i.enabled = d					
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
	
	fn setMult h i =
	(			
		if(i == "") do i = 1.0
		
		i = i as float
		
		h = getHDR h
		if(h == undefined) do return false
		
		case classOf h of
		(
			CoronaBitmap:  h.output.output_amount = i
			bitmapTex:  h.output.output_amount = i
		)
	)
	
	fn getMult h =
	(
		h = getHDR h
		
		case classOf h of
		(
			CoronaBitmap:  return h.output.output_amount
			bitmapTex:  return h.output.output_amount
			default: return 1.0
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
			
			spnLightHDR_Mult.value = getMult h
		)
	
		h = getHDR	 corona.bg_texmapReflect
		if(h != undefined) do 
		(
			btnReflectHDR.caption = filenameFromPath h.filename	
			
			o = getOffset h
			spnReflectHDR.value = offsetToAngle o 
			sldReflectHDR.value = offsetToAngle o
			
			spnReflectHDR_Mult.value = getMult h
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
			rotateHDR (corona.bg_texmap) a

			a = useSettings "LIGHT_HDR_MULT" "string" "r"	
			setMult corona.bg_texmap a
		)
		
		if(doesFileExist reflectHDRPath) do
		(
			corona.bg_overrideReflect = true			
			reflectHDR = CoronaBitmap()
			reflectHDR.filename = reflectHDRPath
			corona.bg_texmapReflect = reflectHDR
			
			a = useSettings "REFLECT_HDR_ANGLE" "float" "r"						
			rotateHDR (corona.bg_texmapReflect) a	

			a = useSettings "REFLECT_HDR_MULT" "string" "r"	
			setMult corona.bg_texmapReflect a			
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
		enableReflections()
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
		enableReflections()
	)
		
	on btnSetupScene pressed do
	(
		
		if(corona == undefined) do return messageBox "Please assign Corona Renderer" title: "Warning!"
				
		defaultView()
				
		setHDRI()
		
		useReflect()
				
		addVFB_Elements()
				
		corona.denoise_filterType = 2
		corona.denoise_blendAmount = 0.5
		
		corona.colorMap_simpleExposure = 1.0
		corona.colorMap_highlightCompression = 2.0
	)
	
	on sldLightHDR changed a do
	(							
		spnLightHDR.value = a 				
		
		tmrRotateLightHDR.active = false
		tmrRotateLightHDR.active = true
	)
	
	on tmrRotateLightHDR tick do
	(
		a = spnLightHDR.value 
		
		rotateHDR (corona.bg_texmap) a
		useSettings "LIGHT_HDR_ANGLE" a "w"
		
		tmrRotateLightHDR.active = false
	)
	
	on tmrRotateReflectHDR tick do
	(
		a = spnReflectHDR.value
		
		rotateHDR (corona.bg_texmapReflect) a
		useSettings "REFLECT_HDR_ANGLE" a "w"
		
		tmrRotateReflectHDR.active = false
	)
	
	on sldReflectHDR changed a do
	(					
		spnReflectHDR.value = a 
				
		tmrRotateReflectHDR.active = false
		tmrRotateReflectHDR.active = true
	)
	
	on sldReflectHDR buttondown do
	(
		tmrRotateReflectHDR.active = false
		tmrRotateReflectHDR.active = true
	)
	
	on sldLightHDR buttondown do
	(
		tmrRotateLightHDR.active = false
		tmrRotateLightHDR.active = true
	)
	
	on spnReflectHDR changed a do
	(
		sldReflectHDR.value = a
		
		tmrRotateReflectHDR.active = false
		tmrRotateReflectHDR.active = true
	)
	
	on spnLightHDR changed a do
	(
		sldLightHDR.value = a
		
		tmrRotateLightHDR.active = false
		tmrRotateLightHDR.active = true
	)
	
	on spnLightHDR_Mult changed v do
	(
		setMult corona.bg_texmap v
		useSettings "LIGHT_HDR_MULT" v "w"
	)
	
	on spnReflectHDR_Mult changed v do
	(
		setMult corona.bg_texmapReflect v
		useSettings "REFLECT_HDR_MULT" v "w"
	)
)


rollout _rStep1  "Highlights"
(	
	listbox lbxLights height: 8
	button btnAdd "Add Light" across: 2
	button btnRemove "Remove Light"
	
	group "Light Settings"
	(
		spinner spnW "W:" range: [0, 99999999, (units.decodeValue "80.0cm")] fieldWidth: 60 type: #worldunits across: 2 align: #left
		spinner spnH "H:" range: [0, 99999999, (units.decodeValue "50.0cm")] fieldWidth: 60 type: #worldunits  align: #left
		spinner spnMult "Mult.:" range: [-100, 999999, 1.0] fieldWidth: 40 type: #float align: #left offset: [0, 10] across: 2
		spinner spnDist "Dist.:" range: [0, 99999999, (units.decodeValue "150.0cm")] fieldWidth: 60 type: #worldunits  align: #left offset: [0, 10] scale: 1.0
	)
	
	button btnPlace "Place Highlight" width: 200 height: 30
	
	timer tmrInteractive active: false 
		
	local callbackLight = undefined
	global lightsList = #()
	local trackCallback = #continue
	
	fn getCurrentLight =
	(
		i = lbxLights.selection
		if(i == 0) do return undefined
		
		l = lightsList[i]
		if(isValidNode l) do return l
		--for l in lightsList where isValidNode l and findString l.name n != undefined do return l
				
		return undefined
	)
	
	fn disableUI d =
	(
		for i in _rStep1.controls do i.enabled = d
		btnPlace.enabled = true
	)
	
	fn trackRay ir placeObj =	
	(		
		if(ir != undefined) then
		(	
			view = (inverse(viewport.getTM())).row4
			viewVector = normalize (view - ir.pos)
					
			refVector = normalize (2 * (dot ir.dir viewVector) *  ir.dir - viewVector)
		
			placeObj.dir = refVector
				
			placeObj.pos = ir.pos 
			in coordsys local move placeObj [0, 0, spnDist.value]
			
			setUserProp placeObj "HiglightDistance" (distance placeObj.pos ir.pos)	
			
			return #continue
		)
	)
	
	fn placeObject objList l =
	(		
		global placeObj = l
				
		fn mouseTrackCallback msg ir obj faceNum shift ctrl alt =
		(
			case msg of
			(				
				#freeMove:
				(						
					return #continue
				)
				#mouseAbort:
				(
					return #end
				)
				#mousePoint:
				(	
					trackRay ir placeObj		
					tmrInteractive.active = true						
					return #continue
				)
				#mouseMove:
				(																								
					trackRay ir placeObj
					return #continue
				)									
			)
		)
				
		trackCallback = mouseTrack on:objList trackCallBack: mouseTrackCallback		
	)
	
	fn getLights = return for l in lights where findString l.name "HighLight_" != undefined collect l

	fn getParams = 
	(
		l = getCurrentLight()
		
		if(l == undefined) do return false
		
		spnW.value = l.width
		spnH.value = l.height
		spnMult.value = l.intensity
		d = getUserProp l "HiglightDistance" 
		if(d != undefined) do spnDist.value = d
	)
	
	fn setParams =
	(
		l = getCurrentLight()		
		if(l == undefined) do return false
		
		l.width = spnW.value
		l.height = spnH.value
		l.intensity = spnMult.value 
		
		d = getUserProp l "HiglightDistance" 
				
		v = spnDist.value - d 
			
		m = d  + v
		
		in coordsys local move l [0, 0, v]
		setUserProp l "HiglightDistance" m			
	)
	
	fn buildList ev nd =
	(
		lightsList = getLights()
		lbxLights.items = for i in lightsList collect i.name
			
		getParams()
	)
	
	fn addLight =
	(
		f = getFilenamePath  (getThisScriptFilename ()) + @"hdri\highlight.exr" 

		h = (units.decodeValue "80.0cm")
		w = (units.decodeValue "50.0cm")
			
		l = CoronaLight targeted:off height: h width: w pos:[0, 0, 0] isSelected: off name: (uniqueName "HighLight_") visibleDirectly: off shape: 1
		
		setUserProp l "HiglightDistance" (units.decodeValue "150.0cm")
			
		s = lbxLights.items.count
		if(s > 0) do try(lbxLights.selection = s + 1) catch()
			
		if(doesFileExist f) do
		(
			l.colorMode = 2
			l.texmap = CoronaBitmap filename: f
		)
	)
		
	fn removeLight =
	(				
		l = getCurrentLight()
		
		if(l != undefined) do delete l
	)
	
	on tmrInteractive tick do 
	(			
		CoronaRenderer.CoronaFp.startInteractive()
		
		tmrInteractive.active = false
	)
	
	on spnW changed v do setParams()
	on spnH changed v do setParams()
	on spnMult changed v do setParams()
	on spnDist changed v do setParams()
		
	on btnAdd pressed do addLight()
	on btnRemove pressed do removeLight()
	
	on _rStep1 open do
	(
		buildList undefined undefined
		
		callbackLight = NodeEventCallback mouseUp:true delay:1000 deleted:buildList added:buildList nameChanged:buildList
	)
	
	on _rStep1 close do
	(
		callbackLight = undefined
	)
	
	on lbxLights selected a do getParams()	

	
	on btnPlace pressed do
	(			
		placeObj = getCurrentLight()
		
		if(placeObj == undefined) do return messageBox "Please add highlight!" title: "Warning!"
		
		disableUI false
				
		o = for i in geometry where i.isHidden == false and placeObj != i  collect i
		--while trackCallback != #stop do placeObject o placeObj
		placeObject o placeObj
				
		trackCallback = #continue
				
		disableUI true
	)
)

fn postProcess =
(
	global rPostProcess
	
	try(destroyDialog rPostProcess) catch()
	
	global postRender = undefined
	
	rollout rPostProcess "Post Process"
	(
		button btnImage "Wait while pre-rendering..." enabled: false border: false width: 640 height: 640 pos: [0, 0]
	
		subrollout subRollout1 "Settings"
		
		timer tmrShowRender "" active: false
				
		fn preRender = renderMap outputMap size:[640,640] filter: true scale: 1.0
		
		fn clearRender = 
		(
			r = bitmap 1 1 color: black 
			btnImage.images = #(r, r, 1,1,1,1,1)
		)
		
		fn showRender now: false = 
		(	
			if(now != true ) do clearRender()
			
			postRender = preRender()
			
			tmrShowRender.interval = 500
			if(now == true ) do tmrShowRender.interval = 1
			
			tmrShowRender.active = true
		)
				
		fn saveImage =
		(
			f = getSaveFileName types: "JPG|*.jpg|PNG|*.png"
			if(f == undefined) do return false
			
			r = preRender()
			
			r.filename = f
			save r
			close r
		)
		
		on rPostProcess open do
		(				
			showRender()
		)
		
		on tmrShowRender tick do
		(
			if(postRender == undefined) do r = bitmap 1 1 color: black 
			
			b = bitmap 640 640 color: black 
			btnImage.images = #(postRender, b, 1,1,1,1,1)
			
			tmrShowRender.active = false
		)
		
		on rPostProcess close do
		(
			try(destroyDialog rPostProcess) catch()
		)
	)
	
	createDialog rPostProcess (640 + 250) 640

	
	ex = "rollout rPostSettings \"Settings\"\n "
	ex += "(\n"
	ex += "checkbox cbxShowAll \"Hide/Show Effects\" checked: true\n\n"
	
		
	for i in 1 to outputMap.mapList.count do 
	(	
		n = outputMap.mapList[i].name
		b = outputMap.blendMode[i]
		o = outputMap.opacity[i] as string 
		s = i as string
		en = if(i == 1) then "false" else "true"
		/* -- Save Settings
		
			blendMode = _rStep0.useSettings ("BLENDMODE" + s) "string" "r"
			if(blendMode != "") do b = blendMode as integer - 1
			
			opacityMode = _rStep0.useSettings ("OPACITY" + s) "string" "r"
			if(opacityMode != "") do o = opacityMode
			
			enableMode = _rStep0.useSettings ("EFFECT" + s) "string" "r"
			if(enableMode == "") do enableMode = "true"
			
			outputMap.blendMode[i] = b
			outputMap.opacity[i] = o as integer
		*/
		
		enableMode = "true"
		
		ex += "group \"" + n + "\" \n"
		ex += "(\n"
		ex += "checkbox cbx" + s + " \"\" width: 24 across: 3 checked: " + enableMode + "  enabled: " + en + " \n"
		ex += 	"dropdownlist ddl" + s+ "\"\" width: 140 enabled: " + en + " offset: [-45, 0] items: blendOptions selection: " + (b + 1) as string + "\n"
		ex += "spinner spn" + s + "\"\" range: [0, 100, " + o + "] type: #integer enabled: " + en + " \n"
		ex += ")\n"
		ex += "on ddl" + s+ " selected v do (\n"
		ex += 	"outputMap.blendMode[" + s +"] = v - 1\n"
		ex += 	"rPostProcess.showRender now: true\n"
		ex += 	"_rStep0.useSettings \"BLENDMODE" + s + "\" v \"w\" \n"
		ex += ")\n"	
		ex += "on spn" + s + " changed v do (\n"
		ex += 	"outputMap.opacity[" + s + "] = v \n"
		ex += 	"rPostProcess.showRender now: true\n"
		ex += 	"_rStep0.useSettings \"OPACITY" + s + "\" v \"w\" \n"		
		ex += ")\n"
		ex += "on cbx" + s + " changed  v do (\n"
		ex += 	"if(v == false) then outputMap.opacity[" + s + "] = 0 else outputMap.opacity[" + s + "] = spn" + s + ".value \n"
		ex += 	"rPostProcess.showRender now: true\n"
		ex += 	"_rStep0.useSettings \"EFFECT" + s + "\" v \"w\" \n"
		ex += ") \n"
	)
	
	ex += "on cbxShowAll changed s do \n"
	ex += "(\n"
	
	for i in 1 to outputMap.mapList.count do 
	(	
		n = outputMap.mapList[i].name
		b = outputMap.blendMode[i]
		o = outputMap.opacity[i] as string 
		s = i as string
		
		if(i != 1) do 
		(
			ex += "if(s == false) then outputMap.opacity[" + s + "] = 0 else outputMap.opacity[" + s + "] = spn" + s + ".value \n"
			ex += "cbx" + s + ".checked = s \n"			
		)
	)

	ex += "rPostProcess.showRender now: true\n"
	ex += ")\n"
	
	ex += "button btnSave \"Save Image\" offset: [0, 15]\n"
	ex += " on btnSave pressed do rPostProcess.saveImage()"
	ex += ")\n"
	
	execute(ex)
	
	rPostProcess.subRollout1.pos = [640, 0]
	rPostProcess.subRollout1.width = 250
	rPostProcess.subRollout1.height = rPostProcess.height
	
	AddSubRollout rPostProcess.subRollout1 rPostSettings		
)

rollout _rStep2  "Render / PostProcess"
(	
	
	group "Render Setup"
	(
		spinner spnRenderSize "Render Size:" range: [640, 99999, 640] type: #integer fieldWidth: 40 align: #left across: 2
		label lblPx " px" align: #left offset: [10, 0]
	)
	group "Render"
	(
		button btnStartInteractive "Start Interactive"
		button btnStartRender "Start Render" height: 30 width: 200
	)
	group "Post Process"
	(
		button btnShowFinal "Show Final Result" 
	)
	
	fn getVFB c: 0 = 
	(	
		f = @"c:\temp\fast-preview\"
		makeDir f
			
		b = CoronaRenderer.CoronaFp.getVfbContent c true true
			
		t = timeStamp()
		b.filename = f + t as string  + ".jpg"
		
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
	
	fn setupPostProcess =
	(
		clearCache()
		
		_rStep0.addVFB_Elements()
		
		
		vfbAlpha = getVFB c:1
		main = getVFB c:0

		-- Beauty / None
		--outputMap = compositeTextureMap()
		l = 1
		outputMap.mapList[l] = main
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.mapList[l].name = "Beauty"
		

		-- Direct Light / SoftLight
		l = 2		
		outputMap.mapList[l] = getVFB c: l
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.blendMode[l] = 15
		outputMap.opacity[l] = 15
		outputMap.mask[l] = vfbAlpha
		outputMap.mapList[l].name = "Direct Light"

		-- Reflect / Screen
		l = 3		
		outputMap.mapList[l] = ColorCorrection()
		outputMap.mapList[l].map = getVFB c: l			
		outputMap.mapList[l].map.coords.blur = 0.01
		--outputMap.mapList[l].lightnessMode = 1
		--outputMap.mapList[l].liftRGB = -0.35			
		outputMap.blendMode[l] = 9
		outputMap.opacity[l] = 45
		outputMap.mask[l] = vfbAlpha
		outputMap.mapList[l].name = "Reflect"

		-- Refract / Screen
		l = 4		
		outputMap.mapList[l] = getVFB c: l
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.blendMode[l] = 9
		outputMap.opacity[l] = 50
		outputMap.mask[l] = vfbAlpha
		outputMap.mapList[l].name = "Refract"
		
		-- Albedo / Overlay
		l = 5		
		outputMap.mapList[l] = getVFB c: l
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.blendMode[l] = 14
		outputMap.opacity[l] = 25
		outputMap.mask[l] = vfbAlpha
		outputMap.mapList[l].name = "Albedo"

		-- AO / Multiply
		l = 6		
		outputMap.mapList[l] = getVFB c: l
		outputMap.mapList[l].coords.blur = 0.01
		outputMap.blendMode[l] = 5
		outputMap.opacity[l] = 25
		outputMap.mask[l] = vfbAlpha
		outputMap.mapList[l].name = "AO"
		
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

		--outRender = renderMap outputMap size:[640,640] filter: true scale: 1.0
		--display outRender
						
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
	
	fn setupRender =
	(
		renderSceneDialog.close()
		
		_rStep0.addVFB_Elements()
		
		renderWidth = spnRenderSize.value
		renderHeight = spnRenderSize.value	
		
		renderSceneDialog.commit()
		renderSceneDialog.update()
	)
	
	fn stopRender = CoronaRenderer.CoronaFp.stopRender()
	fn startRender = 
	(
		setupRender()		
		CoronaRenderer.CoronaFp.resumeRender()
	)
	
	
	fn startInteractive =
	(
		setupRender()
		CoronaRenderer.CoronaFp.startInteractive()
	)
	
	on btnStartRender pressed do startRender()	
	
	on btnStartInteractive pressed do startInteractive()
	
	on btnShowFinal pressed do 
	(			
		try(setupPostProcess()) catch()		
		try(postProcess()) catch(messageBox "Please press \"Setup Scene\" for add default render elements!" title: "Warning!")
	)
	
	on _rStep2 open do
	(
		s = _rStep0.useSettings "RENDER_SIZE" "int" "r"

		spnRenderSize.value = s
		
		setupRender()
	)
	
	on spnRenderSize changed v do
	(
		_rStep0.useSettings "RENDER_SIZE" v "w"
	)
)

rollout _rAbout "About" 
(
	local c = color 200 200 200 
	
	label lbl2 "Fast Preview" 
	label lbl3 szVer 
	
	hyperLink href3 "MastaMan" address: "http://3ddd.ru/users/mastaman" align: #center hoverColor: c visitedColor: c
	label lbl6 "" 
		
	hyperLink href2 "Script Home" address: "http://3ddd.ru/forum/thread/show/skript_prepare_model_3ddd/" align: #center hoverColor: c visitedColor: c
	hyperLink href "http://3ddd.ru" address: "http://3ddd.ru" align: #center hoverColor: c visitedColor: c
)

addRollout _rStep0 fFastRender rolledUp:false
addRollout _rStep1 fFastRender rolledUp:true
addRollout _rStep2 fFastRender rolledUp:false
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