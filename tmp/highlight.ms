trackCallback = #continue

fn placeObject objList =
(	
	placeObj = selection[1]
	
	fn trackRay ir =	
	(		
		if(ir != undefined) then
		(	
			view = (inverse(viewport.getTM())).row4
			viewVector = normalize (view - ir.pos)
					
			refVector = normalize (2 * (dot ir.dir viewVector) *  ir.dir - viewVector)
		
			placeObj.dir = refVector
				
			placeObj.pos = ir.pos 
			in coordsys local move placeObj [0, 0, 100.0]
						
			return #continue
		)
	)
	
	
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
				trackRay ir					
				return #continue
			)
			#mouseMove:
			(																								
				trackRay ir
				return #continue
			)									
		)
	)
			
		
	if(placeObj == undefined) do 
	(
		messageBox "Please select object!" title: "Warning!"
		return trackCallback = #end
	)

	trackCallback = mouseTrack on:objList trackCallBack: mouseTrackCallback
)


o = for i in geometry where i.isHidden == false and placeObj != i  collect i
while trackCallback != #end do placeObject o
trackCallback = #continue
	
	