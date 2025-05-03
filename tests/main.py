from fastapi import FastAPI
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor

class Event(BaseModel):
    venue: str
    name : str
    date: str
    type: str

hostname = 'localhost'
database = 'StelliesAPP'
username = 'postgres'
pwd = '15045'
port_id = 5432
conn = None
cur = None

app = FastAPI()


def get_db_connection():
    return psycopg2.connect(
        host=hostname, 
        dbname=database, 
        user=username, 
        password=pwd, 
        port=port_id,
        cursor_factory=RealDictCursor  
    )

@app.get("/")
async def root():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT *FROM public."event"')  
        venues = cur.fetchall()
        return {"data": venues}
    
    except Exception as error:
        return {"error": error}
    
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()
        

@app.post("/event/")
async def create_event(event: Event):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        # First, check if the venue exists
        cur.execute("SELECT id FROM \"Venue\" WHERE name = '"+ event.venue + "'",)
        venue_id = cur.fetchone()
    
        if not venue_id:
            cur.close()
            conn.close()
            return {"Venue not bound"}
        
        # Insert the new event into the event table
    
        insert_query = """
        INSERT INTO public.event (venue, name, date, type)
        VALUES (""" + str(venue_id["id"]) +""",'"""+ event.name + """','"""+ event.date + """','"""+ event.type + """')
        RETURNING id
        """
        cur.execute(insert_query)
        event_id = cur.fetchone()['id']
        conn.commit()
        return {"id": event_id, **event.dict()}
    
    except Exception as error:
        return {"error": error}
    
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()
        
