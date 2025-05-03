import psycopg2
from psycopg2.extras import RealDictCursor

hostname = 'localhost'
database = 'StelliesAPP'
username = 'postgres'
pwd = '15045'
port_id = 5432
conn = None
cur = None




def get_db_connection():
    return psycopg2.connect(
        host=hostname, 
        dbname=database, 
        user=username, 
        password=pwd, 
        port=port_id,
        cursor_factory=RealDictCursor  
    )


try:
    conn = get_db_connection()
    cur = conn.cursor()
    # First, check if the venue exists
    cur.execute("SELECT id FROM \"Venue\" WHERE name = 'Bohemia'")
    venue_id = cur.fetchone()

    if not venue_id:
        cur.close()
        conn.close()
        raise Exception(status_code=404, detail="Venue not found")
    
    # Insert the new event into the event table
    insert_query = """
    INSERT INTO public.event (venue, name, date, type)
            VALUES (""" + str(venue_id["id"]) +""",'"""+ "test" + """','"""+ "2025-02-20" + """','"""+ "standup-comedy" + """')
            RETURNING id
    """
    cur.execute(insert_query)
    event_id = cur.fetchone()['id']
    conn.commit()
    print({"id": event_id, **dict()})
    
except Exception as error:
    print({"error": error})

finally:
    if cur is not None:
        cur.close()
    if conn is not None:
        conn.close()
