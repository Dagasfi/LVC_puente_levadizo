mtype = {car_ask, ship_ask, car_wait, ship_wait, car_cross, ship_cross, crossing, waiting, raise_bridge, lower_bridge,  raising, lowering, raised, lowered, car_end, ship_end};
mtype bridge_state =  lowered;
mtype order;
int car_count = 0;
int ship_count = 0;
int max_car = 2;
int max_ship = 2;
int type_id;
pid vehicle_id;
int max_crossing_time = 2;
int max_waiting_time = 2;
int max_rt = 1;
int max_lt = 1;
bool moving_bridge = 0;

int semaphore_time; // por ahora no he visto como implementar esta funcionalidad.

chan action = [0] of {mtype, int, pid}; // El int se usa para pasar el orden de los coches (el uid del coche) para asegurar que haya un orden (y barcos)
chan response = [0] of {mtype, int, pid }; 

// Version 1.0: 4 coches y 4 barcos.
active [3] proctype car() {
	pid my_id = _pid;
	mtype car_state = waiting;
	int crossing_time = 0;
	int waiting_time = 0;
	mtype s_response;
	bool asked = 0;
	do
		:: atomic { (asked == 0 && car_state != crossing) -> action!car_ask,1, my_id; asked = 1 }
		:: atomic {
			(car_state == crossing) ->
				if
					:: (crossing_time < max_crossing_time) -> crossing_time ++
					:: (crossing_time >= max_crossing_time )	-> car_state = waiting; crossing_time = 0; asked = 0; action!car_end,2, my_id
				fi
			}
		 :: atomic{ (asked == 1) ->
			response?s_response, 1, eval(my_id);
			if
				:: (s_response == car_wait) -> car_state = waiting; asked = 0
				:: (s_response == car_cross) -> car_state = crossing; asked = 0
			fi
			}
	od
}

active [3] proctype ship() {
	pid my_id = _pid;
	mtype ship_state = waiting;
	int crossing_time = 0;
	int waiting_time = 0;
	mtype s_response;
	bool asked = 0;
	do
		:: atomic { (asked == 0 && ship_state != crossing) -> action!ship_ask,2, my_id; asked = 1 } 
		:: atomic {
			(ship_state == crossing) ->
				if
					:: (crossing_time < max_crossing_time) -> crossing_time ++
					:: (crossing_time >= max_crossing_time )	-> ship_state = waiting; crossing_time = 0; asked = 0; action!ship_end,2, my_id
				fi
			}
		:: atomic{ (asked == 1) -> 
			response?s_response, 2, eval(my_id);
			if
				:: (s_response == ship_wait) -> ship_state = waiting
				:: (s_response == ship_cross) -> ship_state = crossing 
			fi
			}
	od
}

active proctype brdige(){
	
	int raising_time = 0;
	int lowering_time = 0;
	start : do
		:: atomic { (moving_bridge == 0) -> action?order, type_id, vehicle_id;
			if
				:: (order == car_ask && bridge_state == lowered && car_count < max_car) ->  car_count++; response!car_cross,type_id, vehicle_id
				:: (order == ship_ask && bridge_state == raised && ship_count < max_ship) -> ship_count++; response!ship_cross,type_id, vehicle_id

				:: (order == car_ask && bridge_state == raised && ship_count > 0) -> response!car_wait,type_id, vehicle_id
				:: (order == ship_ask && bridge_state == lowered && car_count > 0) -> response!ship_wait,type_id, vehicle_id
				
				:: (order == car_ask && bridge_state == lowered && car_count >= max_car) -> response!car_wait,type_id, vehicle_id
				:: (order == ship_ask && bridge_state == raised && ship_count >= max_ship) -> response!ship_wait,type_id, vehicle_id
				
				:: (order == car_end) -> car_count -- 
				:: (order == ship_end) -> ship_count --

				:: (order == car_ask && bridge_state == raised && ship_count == 0) ->bridge_state = lowering; moving_bridge = 1 
				:: (order == ship_ask && bridge_state == lowered && car_count == 0) ->bridge_state = raising; moving_bridge = 1 
			fi

		}
		:: atomic { (moving_bridge == 1) -> 
			if
				:: (bridge_state == raising && raising_time < max_rt ) -> raising_time ++
				:: (bridge_state == lowering && lowering_time < max_lt) -> lowering_time ++
				:: (bridge_state == raising && raising_time >= max_rt) -> raising_time = 0; bridge_state = raised; ship_count ++; moving_bridge = 0; response!ship_cross,type_id, vehicle_id
				:: (bridge_state == lowering && lowering_time >= max_lt) -> lowering_time = 0; bridge_state = lowered; car_count ++; moving_bridge = 0; response!car_cross,type_id, vehicle_id 
			fi

		 }
	od
		
}

// Garantizar que no se sobrepase el número máximo de coches permitidos cruzando simultáneamente el puente.
ltl max_cars { [] (car_count <= max_car)}

//Garantizar que no se sobrepase el número máximo de barcos permitidos cruzando simultáneamente el puente.
ltl max_ships { [] (ship_count <= max_ship)}

//Garantizar que un coche no cruza hasta que se baje el puente.
ltl crossing_cars { []  ( (bridge_state == lowered) -> (ship_count == 0) )}

// Garantizar que un barco no cruza hasta que se suba el puente.
ltl crossing_ships { []  ( (bridge_state == raised) -> (car_count == 0) )} 

//Garantizar que el puente no se mueve si hay algún vehículo cruzando.
ltl no_moving_bridge {[] ( (moving_bridge == 1) -> (car_count == 0 && ship_count == 0) ) } 

// Si un barco pide para pasar, en algun momento pasara.
// ltl ship_asks {[] ()  } 

// Si un coche pide para pasar, en algun momento pasara.
// ltl car_asks {[] ()  } 
