ActiverecordDIY
=========================

Description
--------------------------
DIY means Do Indexing Yourself

Initial setup
--------------------------
Setup delayed_job in your database:

    bash$ rails generate delayed_job
    bash$ rake db:create db:migrate

You can go into Rails console to setup your model:

    class User < ActiveRecord::Base
      use_json_attributes do |t|
        t.column :name, :string
        t.column :age, :integer
        t.column :gender, :string
      end
      use_index_tables do |t|
        t.indexes_for :age
        t.indexes_for :gender
        t.indexes_for :age, :gender
      end
    end

The ``use_json_attributes`` block follows the syntax of column definitions in Rails migrations. It will cause the following SQL to execute (if the table ``users`` does not exist):

    CREATE TABLE `users` (`guid` int(11) DEFAULT NULL auto_increment PRIMARY KEY, `json` blob, `created_at` datetime, `updated_at` datetime) ENGINE=InnoDB
    ALTER TABLE `users` CHANGE `guid` `guid` varchar(255) NOT NULL
    CREATE INDEX `index_users_on_created_at` ON `users` (`created_at`)

The ``use_index_tables`` block will cause this SQL to execute (if the respective tables does not exist):

    CREATE TABLE `users_age` (`guid` int(11) DEFAULT NULL auto_increment PRIMARY KEY, `age` int(11), `created_at` datetime, `updated_at` datetime) ENGINE=InnoDB
    ALTER TABLE `users_age` CHANGE `guid` `guid` varchar(255) NOT NULL
    CREATE INDEX `main` ON `users_age` (`age`)

    CREATE TABLE `users_gender` (`guid` int(11) DEFAULT NULL auto_increment PRIMARY KEY, `gender` varchar(255), `created_at` datetime, `updated_at` datetime) ENGINE=InnoDB
    ALTER TABLE `users_gender` CHANGE `guid` `guid` varchar(255) NOT NULL
    CREATE INDEX `main` ON `users_gender` (`gender`)

    CREATE TABLE `users_age_gender` (`guid` int(11) DEFAULT NULL auto_increment PRIMARY KEY, `age` int(11), `gender` varchar(255), `created_at` datetime, `updated_at` datetime) ENGINE=InnoDB
    ALTER TABLE `users_age_gender` CHANGE `guid` `guid` varchar(255) NOT NULL
    CREATE INDEX `main` ON `users_age_gender` (`age`, `gender`)

And also, 3 x ``Delayed::Job`` records will be inserted into the DB queue. Each index table gets a dedicated job to populate data from `users` table, paginated, and starting from the most recent row ``ORDER BY created_at DESC``

Main usage
--------------------------

You create instances like any ActiveRecord object:

    john = User.create :name => "John", :age => 11, :gender => "boy"
    joe = User.create :name => "Joe", :age => 10, :gender => "boy"
    jill = User.create :name => "Jill", :age => 12, :gender => "girl"
    sally = User.create :name => "Sally", :age => 9, :gender => "girl"

For each instance created, SQLs like the following will be executed:

    INSERT INTO `users` (`json`, `created_at`, `updated_at`, `guid`) VALUES (x'7b226e616d65223a224a6f686e222c22616765223a31312c2267656e646572223a22626f79227d', '2011-05-18 11:27:26', '2011-05-18 11:27:26', 'bb769b00-636f-012e-386b-60f84737bc8a')
    REPLACE INTO `users_age` (`guid`,`created_at`,`updated_at`,`age`) VALUES ('bb769b00-636f-012e-386b-60f84737bc8a','2011-05-18 11:27:26','2011-05-18 11:27:26',11)
    REPLACE INTO `users_gender` (`guid`,`created_at`,`updated_at`,`gender`) VALUES ('bb769b00-636f-012e-386b-60f84737bc8a','2011-05-18 11:27:26','2011-05-18 11:27:26','boy')
    REPLACE INTO `users_age_gender` (`guid`,`created_at`,`updated_at`,`age`,`gender`) VALUES ('bb769b00-636f-012e-386b-60f84737bc8a','2011-05-18 11:27:26','2011-05-18 11:27:26',11,'boy')

The attributes are saved as a json blob (binary to avoid encoding ambiguities in db config) and stored in ``users`` table. Indexes are populated, referenced by ``guid``.

Now we can query against the ActiveRecord(+DIY) class like we normally do

    User.average(:age).to_f                    #=> 10.5
    User.where(:gender => "boy").maximum(:age) #=> 11
    User.where("age > 10").collect(&:name)     #=> ["John", "Jill"]

Which executes these corresponding SQLs (the last ruby code executes 2 SQL statements):

    SELECT AVG(age) AS avg_id FROM `users_age`
    SELECT MAX(age) AS max_id FROM `users_age_gender` WHERE `users_age_gender`.`gender` = 'boy'
    SELECT guid FROM `users_age` WHERE (age > 10)
    SELECT `users`.* FROM `users` WHERE `users`.`guid` IN ('bb769b00-636f-012e-386b-60f84737bc8a', '17e8c510-6370-012e-386b-60f84737bc8a')

Notes
--------------------------

* ``DelayedJob`` is used to back-populate existing data into new index tables. New objects created will be indexed upon save.
* ``UUID`` is used to generate object ``guid``. However, classes can define custom ``set_guid`` method, e.g. ``self.guid = Digest::SHA1.hexdigest("...")``
* Lots of hacks, be warned.

References
--------------------------
* How FriendFeed Uses MySQL http://bret.appspot.com/entry/how-friendfeed-uses-mysql
* FriendlyORM https://github.com/jamesgolick/friendly

