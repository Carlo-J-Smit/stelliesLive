// Helper function: returns today's weekday name (e.g., "Tuesday")
function getTodayName() {
  // Using toLocaleDateString to get full weekday name
  return new Date().toLocaleDateString('en-US', { weekday: 'long' });
}

function showSidebar(){
    const sidebar = document.querySelector(".sidebar")
    sidebar.style.right = "0"
}

function hideSidebar(){
    const sidebar = document.querySelector(".sidebar")
    sidebar.style.right = "-100%"
}

const product = [
    {
        id: 0,
        image: 'image/Karel_and_Pikkie.png',
        title: 'Karrel & Pikkie',
        category: 'Live Music',
        venue: 'Bohemia',
        date: 'Tuesday'
    },
    {
        id: 1,
        image: 'image/',
        title: 'Soccer',
        category: 'Live Sport',
        venue: 'Bohemia',
        date: 'Monday'
    },
    {
        id: 2,
        image: 'image/Karel_and_Pikkie.png',
        title: '3',
        category: 'Karaoke',
        venue: 'Aandklas',
        date: 'Wednesday'
    },
    {
        id: 3,
        image: 'image/Karel_and_Pikkie.png',
        title: '4',
        category: 'Live Music',
        venue: 'Bohemia',
        date: '2025-02-12'
    },
    
    
    
];

const categories = [...new Set(product.map((item) => { return item }))]

document.getElementById('searchBar').addEventListener('keyup', (e) => {
    const searchData = e.target.value.toLowerCase();
    const filteredData = categories.filter((item) => {
        return (
            item.title.toLowerCase().includes(searchData)
        )
    })
    displayItemAll(filteredData)
});




const displayItemToday = (items) => {
    const container = document.getElementById('TodayBody');
    container.innerHTML = ""; // Clear previous content
  
    // Filter out items with a category of 'none'
    const validItems = items.filter(item => item.category !== 'none');
  
    // Only duplicate if there are more than 2 items
    let loopItems = validItems;
    if (validItems.length > 2) {
      loopItems = [...validItems, ...validItems];
    }
    
    loopItems.forEach((item) => {
      const box = document.createElement('div');
      box.classList.add('box');
      box.innerHTML = `
        <div class='img-box'>
            <img class='images' src="${item.image}" alt="${item.title}">
        </div> 
        <div class='bottom'>
            <p>${item.title}</p>
            <h2>${item.venue}</h2>
            <h3>${item.category}</h3>
            <button>Open</button>
        </div>
      `;
      container.appendChild(box);
    });
  };
      
  displayItemToday(categories);

const displayItemAll = (items) => {
    // Filter out items with category set to 'none'
    const validItems = items.filter(item => item.category !== 'none');

    document.getElementById('root').innerHTML = validItems.map((item) => {
        var { image, title, category, date } = item;
        return (
            `<div class='box'>
                <div class='img-box'>
                    <img class='images' src=${image}></img>
                </div> 
                <div class='bottom'>
                    <p>${title}</p>
                    <h2>${category}</h2>
                    <h3>${date}</h3>
                <button>Open</button>
                </div>
            </div>`
        );
    }).join('');
};



displayItemAll(categories);



// dropdown


// Dropdown logic
const dropdowns = document.querySelectorAll(".dropdown");

dropdowns.forEach(dropdown => {
    const select = dropdown.querySelector(".select");
    const caret = dropdown.querySelector(".caret");
    const menu = dropdown.querySelector(".menu");
    const options = dropdown.querySelectorAll(".menu li");
    const selected = dropdown.querySelector(".selected");

    select.addEventListener("click", () => {
        select.classList.toggle('select-clicked');
        caret.classList.toggle("caret-rotate");
        menu.classList.toggle('menu-open');
    });

    // Loop through options and filter products based on the selected category
    menu.addEventListener('click', (event) => {
        const selectedCategory = event.target.innerText;
        selected.innerText = selectedCategory;
        select.classList.remove('select-clicked');
        caret.classList.remove('caret-rotate');
        menu.classList.remove('menu-open');
        
        const filteredProducts = selectedCategory === 'All' ? product : product.filter(item => item.venue === selectedCategory);
        displayItemAll(filteredProducts);
        document.getElementById('allEventsSearch').innerText = "All Events at " + selectedCategory 
        if (selectedCategory === "All") {document.getElementById('allEventsSearch').innerText = "All Events"}
    });
});


function seamlessScroll() {
    const container = document.getElementById("TodayBody");
    const originalContent = container.innerHTML; // Store original items

    // Duplicate content for seamless looping
    container.innerHTML += originalContent;
    
    let speed = 1; // Adjust speed here

    function scroll() {
        container.scrollLeft += speed;

        // If scrolled past the first set, reset precisely at the duplicate start
        if (container.scrollLeft >= container.scrollWidth / 2) {
            container.scrollLeft = 0;
        }
    }

    setInterval(scroll, 20); // Adjust speed by changing interval time
}

document.addEventListener("DOMContentLoaded", () => {
    let today = new Date().toISOString().slice(0, 10)
    console.log(today)
    const todayName = getTodayName();
    console.log(todayName)


    const todaysEvents = product.filter(event => {
        // Remove a trailing "s" (if any) and compare in lowercase
        const eventDay = event.date.toLowerCase();
        return eventDay === todayName.toLowerCase();
      });

    const todaysEvents2 = product.filter(event => {
      const eventDay = event.date;
        return eventDay === today;
      });




      todaysEventsBoth = todaysEvents.concat(todaysEvents2)

      // Only call displayItem if there is at least one event that matches today's day
      if (todaysEventsBoth.length > 0) {
        displayItemToday(todaysEventsBoth);
      }


    


    displayItemAll(categories);
    console.log(todaysEventsBoth)
    if (todaysEventsBoth.length > 2) {
        console.log("scroll")
    setTimeout(seamlessScroll, 500); // Wait for items to load before scrolling
    }
    if (todaysEventsBoth.length === 2) {
        document.querySelectorAll("#TodayBody .box").forEach(box => {
            box.style.setProperty("width", "38vw", "important");

        });
    } 
    if (todaysEventsBoth.length === 1) {
        document.querySelectorAll("#TodayBody").forEach(box => {
            box.style.setProperty("width", "100%", "important");
            
        });
        document.querySelectorAll("#TodayBody .box").forEach(box => {
            box.style.setProperty("width", "50vw", "important");
            box.style.setProperty("margin-left", "auto", "important");
            box.style.setProperty("margin-right", "auto", "important");
           
        });
    } 
    
});



