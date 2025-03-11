#!/bin/sh

export ODOO_URL=$(awk '/ODOO/ {sub(/^.* *ODOO/, ""); print $2}' /tmp/releases.txt)
export PGADMIN_URL=$(awk '/PGADMIN/ {sub(/^.* *PGADMIN/, ""); print $2}' /tmp/releases.txt)
echo "#!/bin/sh" > /media/icvars
export | egrep "ODOO|PGADMIN" >> /media/icvars
echo "python app.py" >> /media/icvars
chmod 777 /media/icvars
