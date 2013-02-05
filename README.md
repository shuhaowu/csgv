CSGV
====

**Colorado School Grades Visualizer** is a grade visualizer written for 
[Colorado School Grades](http://coloradoschoolgrades.com/) and 
[this Kaggle competition](https://www.kaggle.com/c/visualize-the-state-of-education-in-colorado).

Warning
-------

I am not responsible for this piece of code and its horrors! In my defense,
I wrote this within 2 weeks (when I have time) and most stuff are hacked
together as I was experimenting with different things and styles and was 
under time pressure so I didn't bother refactoring when I'm done with the
experimentations!

**Will I refactor this code?** This is highly unlikely as I don't think I'll
touch this project again, unless there is a really good reason to refactor 
(rewrite) this project.

**Why is the quality of code so bad?** As I've said, I've been experimenting on
what is possible with my setup and taking feedback on what kind of features I
want to add. Sometimes I wrote a feature without considering features that will
be added later on, and the first feature may make the second feature difficult to
accomplish (or some stuff are hard coded or whatever). So I hacked the project
together in a way that works.

Okay, I get it. I wanna look at the source. What do I do?
---------------------------------------------------------

Uh... Okay:

 - `coffeedev/`: This is all the coffeescript files
   - `coffeedev/views/`: All the views!
   - `coffeedev/app.coffee`: Main file to launch everything
 - `static/`: static files like icons, css, javascripts
   - `static/jstemplates/`: During run time these are loaded when necessary to
                            render the views. It's a mess here.
 - `jsondb/`: The databases in json format. There are 2 scripts in here that 
              generates the stuff in the analysis folder
 - `templates/visualizer.html`: The app interface.
 - `school_*.py`: These import the data (you need the data csvs in from the 
                  Kaggle competition which i'm not sure if i could include)
 - `server.py`: Main server file
 - `settings.py`: Main settings file. You need to get your gmaps api key here.

Again, all of these are terrible!

License
-------

All **code** is GPLv3. Stuff I've written is in Creative Commons Attribution 
3.0 Unported. The graphs it generates is also in that if possible. 

Running instructions
--------------------

On the server, you need ujson (`pip install ujson`) and scipy/numpy 
(instructions not provided, go to them). 

Everything on the client side is provided... you can minify if you want.

To compile the coffeescript files, use CoffeeCrispt from my repository
and build using the command `crispt -i coffeedev/ -o static/js/app.js`. 
Attach the flag `-w` if you want to watch for changes and compile. Attach
`-m` for minification.
